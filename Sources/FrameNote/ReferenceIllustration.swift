enum ReferenceIllustration {
    case look(AppearanceSpecimen)
    case layout(LayoutSpecimen)
    case type(TypeSpecimen)
    case ui(InterfaceSpecimen)
    case motion(AnimationSpecimen)
    case palette([UInt32]), gradient([UInt32])
    case pair(String, String, String, String)
}

enum AppearanceSpecimen {
    case swiss, bauhaus, brutal, soft, physical, pixel, terminal
    case paper, outline, dark, deco, memphis, opacity, contrast
    case elevation, icons, themes
}

enum LayoutSpecimen {
    case bento, align, similar, region, target, sidebar, topbar
    case bottomnav, anchors, drawer, skeleton, flex, grid, gutter
    case maxwidth, ratio, stack, sticky, divider, hero, footer
    case master, breakpoint, wrap, fluid, safe, overflow, shift
    case mobilefirst, cover, contain, focal, density, rtl
}

enum TypeSpecimen {
    case scale, tracking, kerning, paragraph, measure, baseline, tabular
    case ellipsis, clamp, fallback, wrap, numeric, italic, variable
    case spacing
}

enum AnimationSpecimen {
    case delay, stagger, spring, scale, crossfade, rotation, press
    case shimmer, shared, keyframes
}

enum InterfaceSpecimen {
    case textarea, combo, slider, stepper, date, segment, upload
    case search, chip, required, steps, menu, command, tooltip
    case popover, accordion, banner, progress, invalid, empty, retry
    case cta, toolbar, table, row, focus, taborder, iconname
    case skip, status, avatars, hover, disabled, readonly, bulk
    case reorder, noresults, loadmore, variants, helper, placeholder, destructive
    case expansion
}
