require "rails_helper"

RSpec.describe RhinoHtml do
  describe ".sanitize" do
    it "keeps the rhino editor's tag set and href attributes" do
      html = '<h1>Title</h1><blockquote><strong>quote</strong></blockquote>' \
             '<pre><code>code</code></pre><p>a <a href="/x" target="_blank">link</a></p>'

      expect(described_class.sanitize(html)).to eq(
        '<h1>Title</h1><blockquote><strong>quote</strong></blockquote>' \
        '<pre><code>code</code></pre><p>a <a href="/x">link</a></p>'
      )
    end

    it "strips disallowed tags but keeps their text" do
      expect(described_class.sanitize("<table><tr><td>cell</td></tr></table>")).to eq("cell")
      expect(described_class.sanitize("<h2>demoted</h2>")).to eq("demoted")
    end

    it "removes script and event handlers entirely" do
      expect(described_class.sanitize('<p onclick="x()">hi</p><script>alert(1)</script>')).to eq("<p>hi</p>")
    end

    it "leaves plain text untouched and returns empty string for blank input" do
      expect(described_class.sanitize("just words")).to eq("just words")
      expect(described_class.sanitize(nil)).to eq("")
      expect(described_class.sanitize("  ")).to eq("")
    end
  end
end
