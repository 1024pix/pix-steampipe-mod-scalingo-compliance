mod "pix_scalingo" { 
  title          = "Pix Scalingo"
  categories     = ["Public Cloud", "Pix"]

  require {
    plugin "francois2metz/scalingo" {
      version = "0.0.8"
    }
  }
}