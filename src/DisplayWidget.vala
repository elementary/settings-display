/*-
 * Copyright (c) 2014-2016 elementary LLC.
 *
 * This software is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Library General Public
 * License as published by the Free Software Foundation; either
 * version 2 of the License, or (at your option) any later version.
 *
 * This software is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Library General Public License for more details.
 *
 * You should have received a copy of the GNU Library General Public
 * License along with this software; if not, write to the
 * Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
 * Boston, MA 02110-1301, USA.
 *
 * Authored by: Corentin Noël <corentin@elementary.io>
 */

public class Display.DisplayWidget : Gtk.EventBox {
    public signal void set_as_primary ();
    public signal void move_display (int delta_x, int delta_y);
    public signal void check_position ();
    public signal void configuration_changed ();
    public signal void active_changed ();

    public DisplayWindow display_window;
    public Gnome.RROutputInfo output_info;
    public Gnome.RROutput output;
    public int delta_x { get; set; default = 0; }
    public int delta_y { get; set; default = 0; }
    public bool only_display { get; set; default = false; }
    private double start_x = 0;
    private double start_y = 0;
    private bool holding = false;
    private Gtk.Button primary_image;

    private int real_width = 0;
    private int real_height = 0;
    private int real_x = 0;
    private int real_y = 0;
    
    struct Resolution {
        uint width;
        uint height;
    }

    public DisplayWidget (Gnome.RROutputInfo output_info, Gnome.RROutput output) {
        display_window = new DisplayWindow (output_info);
        events |= Gdk.EventMask.BUTTON_PRESS_MASK;
        events |= Gdk.EventMask.BUTTON_RELEASE_MASK;
        events |= Gdk.EventMask.POINTER_MOTION_MASK;
        this.output_info = output_info;
        this.output = output;
        output_info.get_geometry (out real_x, out real_y, out real_width, out real_height);
        if (!output_info.is_active ()) {
            real_width = 1280;
            real_height = 720;
        }

        primary_image = new Gtk.Button.from_icon_name ("non-starred-symbolic", Gtk.IconSize.MENU);
        primary_image.margin = 6;
        primary_image.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        primary_image.halign = Gtk.Align.START;
        primary_image.valign = Gtk.Align.START;
        primary_image.clicked.connect (() => set_as_primary ());
        set_primary (output_info.get_primary ());

        var toggle_settings = new Gtk.ToggleButton ();
        toggle_settings.margin = 6;
        toggle_settings.get_style_context ().add_class (Gtk.STYLE_CLASS_FLAT);
        toggle_settings.halign = Gtk.Align.END;
        toggle_settings.valign = Gtk.Align.START;
        toggle_settings.image = new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.MENU);
        toggle_settings.tooltip_text = _("Configure display");

        var label = new Gtk.Label (output_info.get_display_name ());
        label.halign = Gtk.Align.CENTER;
        label.valign = Gtk.Align.CENTER;
        label.expand = true;

        var grid = new Gtk.Grid ();
        grid.attach (primary_image, 0, 0, 1, 1);
        grid.attach (toggle_settings, 2, 0, 1, 1);
        grid.attach (label, 0, 0, 3, 2);
        add (grid);

        var popover_grid = new Gtk.Grid ();
        popover_grid.column_spacing = 12;
        popover_grid.row_spacing = 6;
        popover_grid.margin = 12;
        var popover = new Gtk.Popover (toggle_settings);
        popover.position = Gtk.PositionType.BOTTOM;
        popover.bind_property ("visible", toggle_settings, "active", GLib.BindingFlags.BIDIRECTIONAL);
        popover.add (popover_grid);

        var use_label = new Gtk.Label (_("Use This Display:"));
        use_label.halign = Gtk.Align.END;
        var use_switch = new Gtk.Switch ();
        use_switch.halign = Gtk.Align.START;
        use_switch.active = output_info.is_active ();
        this.bind_property ("only-display", use_switch, "sensitive", GLib.BindingFlags.INVERT_BOOLEAN);

        var resolution_label = new Gtk.Label (_("Resolution:"));
        resolution_label.halign = Gtk.Align.END;

        var resolution_list_store = new Gtk.ListStore (2, typeof (string), typeof (Gnome.RRMode));
        var resolution_combobox = new Gtk.ComboBox.with_model (resolution_list_store);
        resolution_combobox.sensitive = use_switch.active;
        var text_renderer = new Gtk.CellRendererText ();
        resolution_combobox.pack_start (text_renderer, true);
        resolution_combobox.add_attribute (text_renderer, "text", 0);

        var rotation_label = new Gtk.Label (_("Rotation:"));
        rotation_label.halign = Gtk.Align.END;
        var rotation_list_store = new Gtk.ListStore (2, typeof (string), typeof (Gnome.RRRotation));
        var rotation_combobox = new Gtk.ComboBox.with_model (rotation_list_store);
        rotation_combobox.sensitive = use_switch.active;
        text_renderer = new Gtk.CellRendererText ();
        rotation_combobox.pack_start (text_renderer, true);
        rotation_combobox.add_attribute (text_renderer, "text", 0);

        Resolution[] resolutions = {};
        bool resolution_set = false;
        foreach (unowned Gnome.RRMode mode in output.list_modes ()) {
            var mode_width = mode.get_width ();
            var mode_height = mode.get_height ();
            var aspect = make_aspect_string (mode_width, mode_height);

            string text;
            if (aspect != null) {
                text = "%u × %u (%s)".printf (mode_width, mode_height, aspect);
            } else {
                text = "%u × %u".printf (mode_width, mode_height);
            }

            Resolution res = {mode_width, mode_height};
            if (res in resolutions) continue;
            resolutions += res;

            Gtk.TreeIter iter;
            resolution_list_store.append (out iter);
            resolution_list_store.set (iter, 0, text, 1, mode);
            
            if (output.get_current_mode () == mode) {
                resolution_combobox.set_active_iter (iter);
                resolution_set = true;
            }
        }

        popover_grid.attach (use_label, 0, 0, 1, 1);
        popover_grid.attach (use_switch, 1, 0, 1, 1);
        popover_grid.attach (resolution_label, 0, 1, 1, 1);
        popover_grid.attach (resolution_combobox, 1, 1, 1, 1);
        popover_grid.attach (rotation_label, 0, 2, 1, 1);
        popover_grid.attach (rotation_combobox, 1, 2, 1, 1);
        popover_grid.show_all ();
        display_window.attached_to = this;
        destroy.connect (() => display_window.destroy ());
        use_switch.notify["active"].connect (() => {
            output_info.set_active (use_switch.active);
            resolution_combobox.sensitive = use_switch.active;
            rotation_combobox.sensitive = use_switch.active;

            if (rotation_combobox.active == -1) rotation_combobox.set_active (0);
            if (resolution_combobox.active == -1) resolution_combobox.set_active (0);

            if (use_switch.active) {
                get_style_context ().remove_class ("disabled");
            } else {
                get_style_context ().add_class ("disabled");
            }

            configuration_changed ();
            active_changed ();
        });

        if (!output_info.is_active ()) {
            get_style_context ().add_class ("disabled");
        }

        bool rotation_set = false;
        resolution_combobox.changed.connect (() => {
            Value val;
            Gtk.TreeIter iter;
            resolution_combobox.get_active_iter (out iter);
            resolution_list_store.get_value (iter, 1, out val);
            set_geometry (real_x, real_y, (int)((Gnome.RRMode) val).get_width (), (int)((Gnome.RRMode) val).get_height ());
            rotation_set = false;
            rotation_combobox.set_active (0);
            rotation_set = true;
            configuration_changed ();
            check_position ();
        });

        if (!resolution_set) {
            resolution_combobox.set_active (0);
        }

        rotation_combobox.changed.connect (() => {
            Value val;
            Gtk.TreeIter iter;
            rotation_combobox.get_active_iter (out iter);
            rotation_list_store.get_value (iter, 1, out val);

            Gnome.RRRotation old_rotation;
            if (!rotation_set) {
                old_rotation = Gnome.RRRotation.ROTATION_0;
            } else { 
                old_rotation = output_info.get_rotation ();
            } 
            output_info.set_rotation ((Gnome.RRRotation) val);
            switch ((Gnome.RRRotation) val) {
                case Gnome.RRRotation.ROTATION_90:
                    if (old_rotation == Gnome.RRRotation.ROTATION_0 || old_rotation == Gnome.RRRotation.ROTATION_180) {
                        var width = real_width;
                        real_width = real_height;
                        real_height = width;
                    }

                    label.angle = 270;
                    break;
                case Gnome.RRRotation.ROTATION_180:
                    if (old_rotation == Gnome.RRRotation.ROTATION_90 || old_rotation == Gnome.RRRotation.ROTATION_270) {
                        var width = real_width;
                        real_width = real_height;
                        real_height = width;
                    }

                    label.angle = 180;
                    break;
                case Gnome.RRRotation.ROTATION_270:
                    if (old_rotation == Gnome.RRRotation.ROTATION_0 || old_rotation == Gnome.RRRotation.ROTATION_180) {
                        var width = real_width;
                        real_width = real_height;
                        real_height = width;
                    }

                    label.angle = 90;
                    break;
                default:
                    if (old_rotation == Gnome.RRRotation.ROTATION_90 || old_rotation == Gnome.RRRotation.ROTATION_270) {
                        var width = real_width;
                        real_width = real_height;
                        real_height = width;
                    }

                    label.angle = 0;
                    break;
            }

            rotation_set = true;
            configuration_changed ();
            check_position ();
        });

        Gtk.TreeIter iter;

        rotation_list_store.append (out iter);
        rotation_list_store.set (iter, 0, _("None"), 1, Gnome.RRRotation.ROTATION_0);

        if (output_info.supports_rotation (Gnome.RRRotation.ROTATION_90)) {
            rotation_list_store.append (out iter);
            rotation_list_store.set (iter, 0, _("Clockwise"), 1, Gnome.RRRotation.ROTATION_90);
            if (output_info.get_rotation () == Gnome.RRRotation.ROTATION_90) {
                rotation_combobox.set_active_iter (iter);
                label.angle = 270;
                rotation_set = true;
            }
        }

        if (output_info.supports_rotation (Gnome.RRRotation.ROTATION_180)) {
            rotation_list_store.append (out iter);
            rotation_list_store.set (iter, 0, _("Flipped"), 1, Gnome.RRRotation.ROTATION_180);
            if (output_info.get_rotation () == Gnome.RRRotation.ROTATION_180) {
                rotation_combobox.set_active_iter (iter);
                label.angle = 180;
                rotation_set = true;
            }
        }

        if (output_info.supports_rotation (Gnome.RRRotation.ROTATION_270)) {
            rotation_list_store.append (out iter);
            rotation_list_store.set (iter, 0, _("Counterclockwise"), 1, Gnome.RRRotation.ROTATION_270);
            if (output_info.get_rotation () == Gnome.RRRotation.ROTATION_270) {
                rotation_combobox.set_active_iter (iter);
                label.angle = 90;
                rotation_set = true;
            }
        }

        if (!rotation_set) {
            rotation_combobox.set_active (0);
        }

        configuration_changed ();
        check_position ();
    }

    public override bool button_press_event (Gdk.EventButton event) {
        if (only_display) {
            return false;
        }

        start_x = event.x_root;
        start_y = event.y_root;
        holding = true;
        return false;
    }

    public override bool button_release_event (Gdk.EventButton event) {
        if ((delta_x == 0 && delta_y == 0) || only_display) {
            return false;
        }

        var old_delta_x = delta_x;
        var old_delta_y = delta_y;
        delta_x = 0;
        delta_y = 0;
        move_display (old_delta_x, old_delta_y);
        holding = false;
        return false;
    }

    public override bool motion_notify_event (Gdk.EventMotion event) {
        if (holding && !only_display) {
            delta_x = (int)(event.x_root - start_x);
            delta_y = (int)(event.y_root - start_y);
            check_position ();
        }

        return false;
    }

    public void set_primary (bool is_primary) {
        output_info.set_primary (is_primary);
        if (is_primary) {
            ((Gtk.Image) primary_image.image).icon_name = "starred-symbolic";
            primary_image.tooltip_text = _("Is the primary display");
        } else {
            ((Gtk.Image) primary_image.image).icon_name = "non-starred-symbolic";
            primary_image.tooltip_text = _("Set as primary display");
        }
    }

    public void get_geometry (out int x, out int y, out int width, out int height) {
        x = real_x;
        y = real_y;
        width = real_width;
        height = real_height;
    }

    public void set_geometry (int x, int y, int width, int height) {
        real_x = x;
        real_y = y;
        real_width = width;
        real_height = height;
        output_info.set_geometry (real_x, real_y, real_width, real_height);
    }

    public bool equals (DisplayWidget sibling) {
        return output_info.get_display_name () == sibling.output_info.get_display_name ();
    }

    // copied from GCC panel
    public static string? make_aspect_string (uint width, uint height) {
        uint ratio;
        string? aspect = null;

        if (width == 0 || height == 0)
            return null;

        if (width > height) {
            ratio = width * 10 / height;
        } else {
            ratio = height * 10 / width;
        }

        switch (ratio) {
            case 13:
                aspect = "4∶3";
                break;
            case 16:
                aspect = "16∶10";
                break;
            case 17:
                aspect = "16∶9";
                break;
            case 23:
                aspect = "21∶9";
                break;
            case 12:
                aspect = "5∶4";
                break;
                /* This catches 1.5625 as well (1600x1024) when maybe it shouldn't. */
            case 15:
                aspect = "3∶2";
                break;
            case 18:
                aspect = "9∶5";
                break;
            case 10:
                aspect = "1∶1";
                break;
        }

        return aspect;
    }
}
