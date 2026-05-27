/*
 * SPDX-License-Identifier: GPL-2.0-or-later
 * SPDX-FileCopyrightText: 2025 elementary, Inc. <https://elementary.io>
 *
 * Authored by: Leonardo Lemos <leonardolemos@live.com>
 */

public class Display.MonitorLayoutManager : GLib.Object {
    private Settings settings;

    private const string PREFERRED_MONITOR_LAYOUTS_KEY = "preferred-display-layouts";

    public MonitorLayoutManager () {
        Object ();
    }

    construct {
        settings = new Settings ("io.elementary.settings.display");
    }

    public void arrange_monitors (Gee.LinkedList<VirtualMonitor> virtual_monitors) {
        if (virtual_monitors.size == 1) {
            // If there's only one monitor, no need to arrange
            // Cloned monitors only have one virtual monitor so will return here
            return;
        }

        var layout_key = get_layout_key (virtual_monitors);
        // Layouts format are 'a{sa{sa{sv}}}'
        var layouts = settings.get_value (PREFERRED_MONITOR_LAYOUTS_KEY);
        VariantDict? monitors = null;
        if (layouts == null &&
            layouts.lookup (layout_key, "a{sa{sv}}", out monitors) &&
            monitors != null) {

            foreach (var virtual_monitor in virtual_monitors) {
                DisplayTransform transform;
                int x, y;
                if (monitors.lookup (virtual_monitor.id, "(iiu)", out x, out y, out transform)) {
                    virtual_monitor.x = x;
                    virtual_monitor.y = y;
                    virtual_monitor.transform = transform;
                }
            }

            return;
        }

        // If no layout found, we save the current layout to use later
        save_layout (virtual_monitors);
    }

    private void save_layout (Gee.LinkedList<VirtualMonitor> virtual_monitors) {
        var key = get_layout_key (virtual_monitors);
        var layout_variant = build_layout_variant (virtual_monitors);

        var layouts = settings.get_value (PREFERRED_MONITOR_LAYOUTS_KEY);

        add_or_update_layout (layouts, key, layout_variant);
    }

    private string get_layout_key (Gee.LinkedList<VirtualMonitor> virtual_monitors) {
        // Generate a unique key based on the virtual monitors' monitors hashes
        var key = new StringBuilder ();

        foreach (var virtual_monitor in virtual_monitors) {
            foreach (var monitor in virtual_monitor.monitors) {
                key.append (monitor.hash.to_string ());
            }
        }

        return key.str.hash ().to_string ();
    }

    private GLib.Variant build_layout_variant (Gee.LinkedList<VirtualMonitor> virtual_monitors) {
        var dict_builder = new VariantBuilder (VariantType.DICTIONARY);

        foreach (var monitor in virtual_monitors) {
            var props_builder = new VariantBuilder (VariantType.DICTIONARY);
            var key = monitor.monitors.get (0).hash.to_string ();

            var coordinate_x_variant = new Variant.variant (new Variant.int32 (monitor.x));
            var coordinate_y_variant = new Variant.variant (new Variant.int32 (monitor.y));
            var transform_variant = new Variant.variant (new Variant.int32 (monitor.transform));

            props_builder.add_value (new Variant.dict_entry ("x", coordinate_x_variant));
            props_builder.add_value (new Variant.dict_entry ("y", coordinate_y_variant));
            props_builder.add_value (new Variant.dict_entry ("transform", transform_variant));

            var props_variant = props_builder.end ();

            warning (props_variant.print (true));

            dict_builder.add_value (new Variant.dict_entry (key, props_variant));
        }

        return dict_builder.end ();
    }

    private void add_or_update_layout (GLib.Variant layouts, string key, GLib.Variant layout_variant) {
        var layout_builder = new VariantBuilder (VariantType.DICTIONARY);
        bool found = false;

        for (var i = 0; i < layouts.n_children (); i++) {
            var layout = layouts.get_child_value (i);
            var layout_key = layout.get_child_value (0).get_string ();

            if (layout_key == key) {
                // Update existing layout
                layout_builder.add_value (new Variant.dict_entry (key, layout_variant));
                found = true;
            } else {
                // Keep existing layout
                layout_builder.add_value (new Variant.dict_entry (layout_key, layout));
            }
        }

        if (!found) {
            // Add new layout
            layout_builder.add_value (new Variant.dict_entry (key, layout_variant));
        }

        settings.set_value (PREFERRED_MONITOR_LAYOUTS_KEY, layout_builder.end ());
    }

    private bool is_virtual_monitors_cloned (Gee.LinkedList<VirtualMonitor> virtual_monitors) {
        foreach (var monitor in virtual_monitors) {
            if (monitor.x != 0 || monitor.y != 0) {
                return false;
            }
        }

        return true;
    }
}
