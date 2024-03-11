mod "pix_scalingo" { 
  title          = "Pix Scalingo"
  categories     = ["Public Cloud", "Pix"]

  require {
    plugin "francois2metz/scalingo" {
      min_version = "0.15.0"
    }
  }
}
