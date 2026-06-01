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
        Variant? monitors = null;
        if (layouts != null) {
            monitors = layouts.lookup_value (layout_key, VariantType.VARDICT);
            foreach (var virtual_monitor in virtual_monitors) {
                Variant? props = monitors.lookup_value (virtual_monitor.id, VariantType.VARDICT);
                if (props != null) {
                    int32 x = 0, y = 0;
                    uint32 t = 0;
                    bool p = false;
                    if (props.lookup ("x", "i", out x) &&
                        props.lookup ("y", "i", out y) &&
                        props.lookup ("transform", "u", out t) &&
                        props.lookup ("primary", "b", out p)) {

                        virtual_monitor.x = x;
                        virtual_monitor.y = y;
                        virtual_monitor.transform = t;
                        virtual_monitor.primary = p;
                     } else {
                         warning ("property setting missing for monitor %s", virtual_monitor.get_display_name ());
                     }
                } else {
                    warning ("no property dictionary found for monitor.id %s", virtual_monitor.get_display_name ());
                }
            }

            return;
        } else {
            warning ("layout key %s not found", layout_key);
        }

        // If no layout found, we save the current layout to use later
        save_layout (virtual_monitors);
    }

    public void save_layout (Gee.LinkedList<VirtualMonitor> virtual_monitors) {
        var save_key = get_layout_key (virtual_monitors);

        var monitor_dict = new VariantDict ();
        foreach (var monitor in virtual_monitors) {
            var props_dict = new VariantDict ();
            // We save three properties for now, may want to save more later
            props_dict.insert_value ("x", new Variant.int32 (monitor.x));
            props_dict.insert_value ("y", new Variant.int32 (monitor.y));
            props_dict.insert_value ("transform", new Variant.uint32 (monitor.transform));
            props_dict.insert_value ("primary", new Variant.boolean (monitor.primary));
            monitor_dict.insert_value (monitor.id, props_dict.end ());
        }

        // Add or update the layouts setting
        var layouts = settings.get_value (PREFERRED_MONITOR_LAYOUTS_KEY);
        var layouts_dict = new VariantDict (layouts);
        layouts_dict.insert_value (save_key, monitor_dict.end ());

        // Save to settings
        //NOTE The variant yielded by VariantDict.end () always has type "a{sv}"
        settings.set_value (PREFERRED_MONITOR_LAYOUTS_KEY, layouts_dict.end ());
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
}
