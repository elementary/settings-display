/*
 * Headless tests for layout logic (no GTK). We simulate a subset of the
 * geometry algorithms used by DisplaysOverlay and VirtualMonitor to ensure
 * correctness with 3+ monitors and edge/overlap cases.
 */

public class TestVM : GLib.Object {
    public int x { get; set; }
    public int y { get; set; }
    public int w { get; set; }
    public int h { get; set; }

    public TestVM (int x, int y, int w, int h) {
        this.x = x; this.y = y; this.w = w; this.h = h;
    }
}

namespace Layout {
    public void set_origin_zero (GLib.List<TestVM> vms) {
        int min_x = int.MAX;
        int min_y = int.MAX;
        foreach (unowned var vm in vms) {
            min_x = int.min (min_x, vm.x);
            min_y = int.min (min_y, vm.y);
        }
        if (min_x == 0 && min_y == 0) return;
        foreach (unowned var vm in vms) {
            vm.x -= min_x; vm.y -= min_y;
        }
    }

    public bool intersects (TestVM a, TestVM b, out int ovw, out int ovh) {
        int ax2 = a.x + a.w, ay2 = a.y + a.h;
        int bx2 = b.x + b.w, by2 = b.y + b.h;
        ovw = int.max (0, int.min (ax2, bx2) - int.max (a.x, b.x));
        ovh = int.max (0, int.min (ay2, by2) - int.max (a.y, b.y));
        return ovw > 0 && ovh > 0;
    }

    // Resolve overlaps by moving B minimally away from A along smaller overlap axis
    public bool resolve_overlap_once (TestVM a, TestVM b) {
        int ovw, ovh;
        if (!intersects (a, b, out ovw, out ovh)) return false;
        if (ovw <= ovh) {
            if (b.x < a.x) b.x -= ovw; else b.x += ovw;
        } else {
            if (b.y < a.y) b.y -= ovh; else b.y += ovh;
        }
        return true;
    }

    public void resolve_all_overlaps (GLib.List<TestVM> vms, uint max_iter = 16) {
        uint iter = 0;
        while (iter++ < max_iter) {
            bool moved = false;
            for (int i = 0; i < (int) vms.length (); i++) {
                for (int j = i + 1; j < (int) vms.length (); j++) {
                    moved = resolve_overlap_once (vms.nth_data (i), vms.nth_data (j)) || moved;
                }
            }
            if (!moved) break;
        }
    }

    public bool is_connected_pair (TestVM a, TestVM b) {
        // Adjoin: touch on an edge (inclusive) without overlapping interior
        bool x_adjacent = (a.x + a.w == b.x) || (b.x + b.w == a.x);
        bool y_overlap = !(a.y + a.h <= b.y || b.y + b.h <= a.y);
        bool y_adjacent = (a.y + a.h == b.y) || (b.y + b.h == a.y);
        bool x_overlap = !(a.x + a.w <= b.x || b.x + b.w <= a.x);
        return (x_adjacent && y_overlap) || (y_adjacent && x_overlap);
    }

    public bool is_connected_all (GLib.List<TestVM> vms) {
        if (vms.length () <= 1) return true;
    var seen = new GLib.HashTable<TestVM,bool> (GLib.direct_hash, GLib.direct_equal);
    var queue = new GLib.Queue<TestVM> ();
        var first = vms.nth_data (0);
        seen.insert (first, true);
        queue.push_tail (first);
        while (!queue.is_empty ()) {
            var cur = queue.pop_head ();
            foreach (unowned var vm in vms) {
                if (seen.lookup (vm)) continue;
                if (is_connected_pair (cur, vm)) {
                    seen.insert (vm, true);
                    queue.push_tail (vm);
                }
            }
        }
        return seen.size () == vms.length ();
    }
}

int failures = 0;
void assert_true (bool cond, string msg) {
    if (!cond) {
        critical ("Assertion failed: %s", msg);
        failures++;
    }
}

int main (string[] args) {
    // Test 1: Three displays, initially overlapping; resolve, normalize, and validate connectivity
    var vms = new GLib.List<TestVM> ();
    vms.append (new TestVM (0, 0, 1920, 1080));
    vms.append (new TestVM (1800, 0, 1920, 1080)); // overlaps 120px on X
    vms.append (new TestVM (3600, 100, 1280, 1024)); // slightly below and to the right

    Layout.resolve_all_overlaps (vms);
    Layout.set_origin_zero (vms);
    int _ovw, _ovh;
    assert_true (!Layout.intersects (vms.nth_data (0), vms.nth_data (1), out _ovw, out _ovh), "VM0/VM1 should not overlap after resolve");
    assert_true (!Layout.intersects (vms.nth_data (1), vms.nth_data (2), out _ovw, out _ovh), "VM1/VM2 should not overlap after resolve");

    // Expect connectivity after minor adjustments
    assert_true (Layout.is_connected_all (vms), "All VMs should be connected");

    // Test 2: Vertical stacking with same X, ensure normalization keeps origin at (0,0)
    var v2 = new GLib.List<TestVM> ();
    v2.append (new TestVM (100, 200, 1600, 900));
    v2.append (new TestVM (100, 1100, 1600, 900));
    Layout.set_origin_zero (v2);
    assert_true (v2.nth_data (0).x == 0 && v2.nth_data (0).y == 0, "Origin normalized to (0,0)");
    assert_true (v2.nth_data (1).x == 0 && v2.nth_data (1).y == 900, "Second stacked below first at y=height");

    // Test 3: Edge adjacency detection
    var a = new TestVM (0, 0, 100, 100);
    var b = new TestVM (100, 10, 100, 50); // touches a's right edge
    assert_true (Layout.is_connected_pair (a, b), "Edge adjacency should be connected");

    // Test 4: Same Y alignment with exact adjacency across three displays
    var t4 = new GLib.List<TestVM> ();
    t4.append (new TestVM (0, 0, 1000, 800));
    t4.append (new TestVM (1000, 0, 1000, 800));
    t4.append (new TestVM (2000, 0, 1000, 800));
    assert_true (!Layout.intersects (t4.nth_data (0), t4.nth_data (1), out _ovw, out _ovh), "T4: 0/1 no overlap");
    assert_true (!Layout.intersects (t4.nth_data (1), t4.nth_data (2), out _ovw, out _ovh), "T4: 1/2 no overlap");
    assert_true (Layout.is_connected_all (t4), "T4: all connected along same Y");

    // Test 5: Same Y with overlaps; resolver should separate into no-overlap configuration and keep connectivity
    var t5 = new GLib.List<TestVM> ();
    t5.append (new TestVM (0, 0, 1000, 800));
    t5.append (new TestVM (900, 0, 1000, 800)); // overlaps with first by 100px
    t5.append (new TestVM (1900, 0, 1000, 800)); // overlaps with second by 0px (adjacent or slight overlap if math changes)
    Layout.resolve_all_overlaps (t5);
    assert_true (!Layout.intersects (t5.nth_data (0), t5.nth_data (1), out _ovw, out _ovh), "T5: 0/1 resolved");
    assert_true (!Layout.intersects (t5.nth_data (1), t5.nth_data (2), out _ovw, out _ovh), "T5: 1/2 resolved");
    assert_true (Layout.is_connected_all (t5), "T5: all connected after resolve");

    // Test 6: Vertical stacking with same X (three displays)
    var t6 = new GLib.List<TestVM> ();
    t6.append (new TestVM (0, 0, 1200, 900));
    t6.append (new TestVM (0, 900, 1200, 900));
    t6.append (new TestVM (0, 1800, 1200, 900));
    assert_true (!Layout.intersects (t6.nth_data (0), t6.nth_data (1), out _ovw, out _ovh), "T6: 0/1 stacked no overlap");
    assert_true (!Layout.intersects (t6.nth_data (1), t6.nth_data (2), out _ovw, out _ovh), "T6: 1/2 stacked no overlap");
    assert_true (Layout.is_connected_all (t6), "T6: stacked connected");

    // If we reached here, all tests passed
    if (failures == 0) message ("layout tests passed");
    return failures == 0 ? 0 : 1;
}
