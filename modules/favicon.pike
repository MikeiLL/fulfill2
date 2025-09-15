#!/usr/bin/env pike
#if constant(G)
inherit annotated;
#else

int main(int argc, array(string) argv) {
  mapping args = Arg.parse(argv); // parsed arguments
  mapping cfg = MIME.parse_headers(Stdio.read_file("favicon.cfg") || "")[0]; // RFC822 style
  constant DEFAULTS = ([
    "size": 64,
    "text": "",
    "primarycolor": "#fff",
    "textcolor": "#000",
    "shape": "none",
    "secondarycolor": "#bbb",
  ]);
  cfg = DEFAULTS | cfg;
  // if no file will parse to an empty mapping.
  if (args->help) {
    write(#"USAGE: %s [text] [primaryColor] [textcolor] [shape] [secondaryColor]
    SUPPORTS a favicon.cfg file in current directory.
    OPTIONAL FLAGS
    --help
    --listfonts
    --shapes
    EXAMPLES:
      %<s C magenta aliceblue
      %<s X magenta rebeccapurple circle darkblue
    ", basename(argv[0]));
    return 0;
  }
  if (args->listfonts) {
    write("Fonts in %s: %O\n", "/Users/mikekilmer/Library/Fonts", sort(indices(Image.Fonts.list_fonts())));
  }
  if (args->shapes) {
    write("Shape Options: %O\n", sort(({
      "square (default)",
      "hsplit (split horizontal)",
      "vsplit (split vertical)",
      "dsplitl (split diagonal left top to right bottom)",
      "dsplitr (split diagonal right top to left bottom)",
      "hstripe (stripe horizontal)",
      "vstripe (stripe vertical)",
      "star (of David)",
      "diamond (rotated square)"
    })));
  }
  array cmdlineargs = "text primarycolor textcolor shape secondarycolor" / " ";
  // now update cfgs if args present
  foreach (args[Arg.REST]; int i; string arg) cfg[cmdlineargs[i]] = arg;
  Stdio.write_file("favicon.png",Image.PNG.encode(generate_favicon(cfg)));
}
#endif

#if constant(G)
@export:
#endif
Image.Image generate_favicon(mapping cfg){
  int image_size = (int) cfg->size || 64;
  int desired_height = image_size - 4; //2px padding top and bottom
  Image.Image ltr;
  // Find the biggest letter of specified font that fits within threshold
  for (int sz = image_size / 2; sz < 1024; ++sz) {
    object font = Image.Fonts.open_font(cfg->font || "Lato", sz, Image.Fonts.BOLD);
    Image.Image tryme = font->write(cfg->text)->autocrop();
    if (tryme->ysize() <= desired_height) ltr = tryme;
    if (tryme->ysize() >= desired_height) break;
  }
  // https://pike.lysator.liu.se/generated/manual/modref/ex/predef_3A_3A/Image/Color.html#Color
  array secondarycolor = Colors.parse_color(cfg->secondarycolor); // RGB array
  Image.Image icon = Image.Image(image_size, image_size, @Colors.parse_color(cfg->primarycolor));
  array txtcol = Colors.parse_color(cfg->textcolor);

  switch (cfg->shape) {
    case "circle":
      icon->setcolor(@secondarycolor);
      int radius = image_size/2 - 1;
      int rsq = radius ** 2;
      for (int x = 0; x < image_size / 2; ++x)
        for (int y = 0; y < image_size / 2; ++y)
          if (x*x + y*y < rsq) {
            icon->setpixel(image_size / 2 + x, image_size / 2 + y); // lower right
            icon->setpixel(image_size / 2 + x, image_size / 2 - y); // upper right
            icon->setpixel(image_size / 2 - x, image_size / 2 + y); // lower left
            icon->setpixel(image_size / 2 - x, image_size / 2 - y); // upper left
          }
      break;
    case "hsplit": icon->box(image_size / 2,0, image_size,image_size, @secondarycolor); werror("Split H"); break;
    case "vsplit": icon->box(0, image_size /2, image_size,image_size, @secondarycolor); werror("Split V"); break;
    case "dsplitl": icon->setcolor(@secondarycolor)->polyfill( ({ 0,0, image_size,0, image_size,image_size }) ); break;
    case "dsplitr": icon->setcolor(@secondarycolor)->polyfill( ({ 0,0, image_size,0, 0,image_size }) ); break;
    case "hstripe": case "vstripe": {
      constant STRIPE_COUNT = 6; //total, 3 of each colour
      for(int i=1; i < STRIPE_COUNT; i+=2) { // paint stripes 1 three and five (0 - 5)
        int start = image_size * i / STRIPE_COUNT;
        int end = image_size * (i + 1) / STRIPE_COUNT;
        if (cfg->shape == "hstripe") icon->box(0, start, image_size, end, @secondarycolor);
        else icon->box(start, 0, end, image_size, @secondarycolor);
      }
      break;
    }
    case "dtriangle": icon->setcolor(@secondarycolor)->polyfill( ({ 1,1, image_size - 1,1, image_size/2,image_size - 1 }) ); break;
    case "utriangle": icon->setcolor(@secondarycolor)->polyfill( ({ image_size/2,1, image_size - 1,image_size-1, 1,image_size-1 }) ); break;
    case "6star": {
      icon->setcolor(@secondarycolor)->polyfill( ({ 1,image_size*3/4, image_size/2,1, image_size-1,image_size*3/4 }) ) // up triangle
      ->polyfill( ({ 1,image_size/4, image_size/2,image_size-1, image_size-1,image_size/4 }) ); // down triangle
      break;}
    case "diamond": icon->setcolor(@secondarycolor)->polyfill( ({ image_size/2,1, image_size - 1,image_size/2, image_size/2,image_size - 1, 1,image_size/2 }) ); break;
    case "none": case "square": break;
    default: exit(1, "Unrecognized shape %O\n", cfg->shape);
  }
  icon->paste_mask(Image.Image(ltr->xsize(), ltr->ysize(), @txtcol),ltr, (image_size - ltr->xsize()) / 2, (image_size - ltr->ysize()) / 2);
  return icon;
}

protected void create(string name) {
  #if constant(G)
  ::create(name);
  #endif
  string fontspath = "/Users/mikekilmer/Library/Fonts";
  Image.Fonts.set_font_dirs(({fontspath}));
}
