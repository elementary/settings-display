/*
 * Copyright 2025 elementary, Inc. (https://elementary.io)
 * SPDX-License-Identifier: LGPL-3.0-or-later
 */

public class Display.MonitorLabel : Gtk.Window, PantheonWayland.ExtendedBehavior {
    private const int SPACING = 12;
    private const string COLORED_STYLE_CSS = """
    .label-%d {
        background-color: alpha(%s, 0.8);
        color: %s;
    }
    """;

    public int index { get; construct; }
    public string label { get; construct; }
    public string bg_color { get; construct; }
    public string text_color { get; construct; }

    public MonitorLabel (int index, string label, string bg_color, string text_color) {
        Object (
            index: index,
            label: label,
            bg_color: bg_color,
            text_color: text_color
        );
    }

    construct {
        // Construct a label roughly matching that shown in Classic session
        child = new Gtk.Label (label) {
            margin_start = 12,
            margin_end = 12,
            margin_top = 12,
            margin_bottom = 12,
            halign = CENTER,
            valign = CENTER
        };
        child.add_css_class (Granite.STYLE_CLASS_H3_LABEL);

        decorated = false;
        resizable = false;
        deletable = false;
        can_focus = false;
        titlebar = new Gtk.Grid () { visible = false };

        var provider = new Gtk.CssProvider ();
        try {
            provider.load_from_string (COLORED_STYLE_CSS.printf (index, bg_color, text_color));
            add_css_class ("label-%d".printf (index));
            add_css_class ("monitor-label");

            Gtk.StyleContext.add_provider_for_display (
                Gdk.Display.get_default (),
                provider,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        } catch (Error e) {
            warning ("Failed to load CSS: %s", e.message);
        }

        child.realize.connect (on_realize);
    }

    private void on_realize () requires (!(Gdk.Display.get_default () is Gdk.X11.Display )) {
        if (!(this is PantheonWayland.ExtendedBehavior)) {
            return;
        }

        connect_to_shell ();
        ((PantheonWayland.ExtendedBehavior)(this)).make_monitor_label (index);
    }
}
