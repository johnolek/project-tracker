class EmbedController < ApplicationController
  # The whole embed flow is deliberately identity-free (PROJ-89): loaded cross-
  # site inside an iframe where third-party cookies are blocked, so there is no
  # session to protect and CSRF tokens would guard nothing. The iframe design
  # keeps every request same-origin, so no CORS headers are needed either.
  skip_forgery_protection

  layout "embed"

  # The loader script injected by a host page's <script src=".../embed.js">.
  # Plain vanilla JS (no build step); the frame path is the only server value.
  def loader
    render :loader, content_type: "text/javascript"
  end

  # The framed submission form. Renders only for an allowlisted origin; any
  # other origin gets a 404 so the iframe never becomes visible. Framing is
  # opened to the requesting origin alone — a per-response frame-ancestors CSP
  # plus dropping the global X-Frame-Options, scoped to this response only.
  def frame
    @domain = EmbedDomain.for_origin(params[:origin])
    @origin = EmbedDomain.normalized_origin(params[:origin])
    return head :not_found unless @domain && @origin

    @item_types = @domain.organization.item_types.ordered.map(&:name)
    @default_type = @domain.default_item_type if @item_types.include?(@domain.default_item_type)

    response.headers["Content-Security-Policy"] = "frame-ancestors #{@origin}"
    response.headers.delete("X-Frame-Options")
  end

  # Multipart submission from the framed widget. Re-validates the origin server-
  # side (never trusting the client), then creates a published item in the
  # mapped project. Responds { key, url } for the widget's success state.
  def create
    domain = EmbedDomain.for_origin(params[:origin])
    return render json: { errors: [ "Unrecognized origin" ] }, status: :not_found unless domain

    item = build_item(domain: domain)

    if item.save
      render json: { key: item.key, url: project_item_url(item.project, item) }, status: :created
    else
      render json: { errors: item.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  # Assembles (but does not save) the submitted item: mapped project, first
  # workflow status, the pill-selected item type, source "embed", the page
  # context stashed in metadata, and notes built from the description plus any
  # screenshot embedded as an ActionText attachment.
  #
  # @param domain [EmbedDomain]
  # @return [Item]
  def build_item(domain:)
    organization = domain.organization

    domain.project.items.new(
      title: params[:title].to_s.strip,
      item_type: submitted_item_type(organization),
      source: "embed",
      status: organization.statuses.ordered.first,
      metadata: submitted_metadata,
      notes: composed_notes
    )
  end

  # Accepts any type configured for the organization (the same canonical list
  # the frame offers as pills); anything unrecognized or absent falls back to
  # "idea", or to the org's first configured type when "idea" itself has been
  # removed — lenient by design, never a type the org doesn't have.
  #
  # @param organization [Organization]
  # @return [String]
  def submitted_item_type(organization)
    submitted = params[:item_type].to_s.downcase
    return submitted if organization.item_types.exists?(name: submitted)

    organization.item_types.exists?(name: "idea") ? "idea" : organization.item_types.ordered.first&.name
  end

  # Page context the loader forwarded, kept out of the notes body and in the
  # general-purpose metadata jsonb. Blank fields are dropped.
  #
  # @return [Hash]
  def submitted_metadata
    {
      "page_url" => params[:page_url],
      "viewport" => params[:viewport],
      "user_agent" => params[:user_agent]
    }.reject { |_key, value| value.blank? }
  end

  # Notes rich text: the description as HTML paragraphs, followed by the
  # screenshot (when present) as an ActionText attachment so it renders in the
  # existing notes view and surfaces through the attachments API.
  #
  # @return [String]
  def composed_notes
    parts = [ helpers.simple_format(params[:description].to_s) ]
    parts << screenshot_attachment_html if params[:screenshot].present?
    parts.compact.join
  end

  # @return [String, nil] the <action-text-attachment> HTML for the uploaded
  #   screenshot, or nil when nothing was attached
  def screenshot_attachment_html
    upload = params[:screenshot]
    blob = ActiveStorage::Blob.create_and_upload!(
      io: upload.to_io,
      filename: upload.original_filename,
      content_type: upload.content_type
    )
    ActionText::Attachment.from_attachable(blob).to_html
  end
end
