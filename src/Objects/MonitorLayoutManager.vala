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

    public void save_layout (Gee.LinkedList<VirtualMonitor> virtual_monitors) {
        //Build the layout variant
        //NOTE The variant yielded by VariantDict.end () always has type "a{sv}"
        var dict_builder = new VariantDict ();
        foreach (var monitor in virtual_monitors) {
            var props_builder = new VariantDict ();
            // We save three properties for now, may want to save more later
            props_builder.insert ("x", "v", new Variant.int32 (monitor.x));
            props_builder.insert ("y", "v", new Variant.int32 (monitor.y));
            props_builder.insert ("transform", "v", new Variant.uint32 (monitor.transform));
            var props_variant = props_builder.end ();
            debug (props_variant.print (true));
            dict_builder.insert_value (monitor.id, props_variant);
        }

        var layout_variant = dict_builder.end ();

        // Add or update the layouts setting
        var save_key = get_layout_key (virtual_monitors);
        var layouts = settings.get_value (PREFERRED_MONITOR_LAYOUTS_KEY);
        dict_builder = new VariantDict (layouts);
        dict_builder.insert_value (save_key, layout_variant);

        // Save to settings
        settings.set_value (PREFERRED_MONITOR_LAYOUTS_KEY, dict_builder.end ());
    }

    private string get_layout_key (Gee.LinkedList<VirtualMonitor> virtual_monitors) {
        // Generate a unique key based on the virtual monitors' monitors hashes
        var key = new StringBuilder ();

        foreach (var virtual_monitor in virtual_monitors) {
            foreach (var monitor in virtual_monitor.monitors) {
                key.append (virtual_monitor.id);
            }
        }

        return key.str;
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
