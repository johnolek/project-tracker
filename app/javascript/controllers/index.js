// With esbuild, controllers register explicitly: import and register new
// controllers here (or run rails stimulus:manifest:update).
import { application } from "./application"

import NavbarController from "./navbar_controller"
application.register("navbar", NavbarController)

import BoardController from "./board_controller"
application.register("board", BoardController)
