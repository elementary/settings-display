/*-
 * Copyright (c) 2014-2018 elementary LLC.
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

namespace Display.Utils {
    public static bool has_touchscreen () {
        weak Gdk.Display? display = Gdk.Display.get_default ();
        if (display != null) {
            var manager = display.get_device_manager ();
            GLib.List<weak Gdk.Device> devices = manager.list_devices (Gdk.DeviceType.SLAVE);
            foreach (weak Gdk.Device device in devices) {
                if (device.input_source == Gdk.InputSource.TOUCHSCREEN) {
                    return true;
                }
            }
        }

        return false;
    }
}
