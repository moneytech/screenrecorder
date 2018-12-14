/*
* Copyright (c) 2018 mohelm97 (https://github.com/mohelm97/screenrecorder)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Mohammed ALMadhoun <mohelm97@gmail.com>
*/

namespace ScreenRecorder { 
    public class MainWindow : Gtk.ApplicationWindow  {
        private enum CaptureType {
            SCREEN,
            AREA
        }
        private FFmpegWrapper? ffmpegwrapper;
        private CaptureType capture_mode = CaptureType.SCREEN;
        private Gtk.Grid grid;
        private Gtk.ButtonBox actions;
        private Gtk.Button record_btn;
        private Gtk.Button stop_btn;
        private Gtk.Switch pointer_switch;
        private Gtk.Switch borders_switch;
        private Gtk.ComboBoxText format_cmb;

        private bool recording = false;
        private int delay;
        private int framerate;
        private string tmpfilepath;
        private int last_recording_width = 0;
        private int last_recording_height = 0;

        public MainWindow (Gtk.Application app){
            Object (
                application: app,
                border_width: 6,
                resizable: false
            );
        }

        construct {
            GLib.Settings settings = ScreenRecorderApp.settings;

            var all = new Gtk.RadioButton (null);
            all.image = new Gtk.Image.from_icon_name ("grab-screen-symbolic", Gtk.IconSize.DND);
            all.tooltip_text = _("Grab the whole screen");

            var selection = new Gtk.RadioButton.from_widget (all);
            selection.image = new Gtk.Image.from_icon_name ("grab-area-symbolic", Gtk.IconSize.DND);
            selection.tooltip_text = _("Select area to grab");

            var radio_grid = new Gtk.Grid ();
            radio_grid.halign = Gtk.Align.CENTER;
            radio_grid.column_spacing = 24;
            radio_grid.margin = 24;
            radio_grid.get_style_context ().add_class (Granite.STYLE_CLASS_ACCENT);
            radio_grid.add (all);
            radio_grid.add (selection);

            var pointer_label = new Gtk.Label (_("Grab mouse pointer:"));
            pointer_label.halign = Gtk.Align.END;

            pointer_switch = new Gtk.Switch ();
            pointer_switch.halign = Gtk.Align.START;

            var borders_label = new Gtk.Label (_("Show borders:"));
            borders_label.halign = Gtk.Align.END;

            borders_switch = new Gtk.Switch ();
            borders_switch.halign = Gtk.Align.START;

            var delay_label = new Gtk.Label (_("Delay in seconds:"));
            delay_label.halign = Gtk.Align.END;

            var delay_spin = new Gtk.SpinButton.with_range (0, 15, 1);

            var framerate_label = new Gtk.Label (_("Frame rate:"));
            framerate_label.halign = Gtk.Align.END;

            var framerate_spin = new Gtk.SpinButton.with_range (1, 120, 1);

            var format_label = new Gtk.Label (_("Format:"));
            format_label.halign = Gtk.Align.END;

            format_cmb = new FormatComboBox (settings.get_string ("format"));

            record_btn = new Gtk.Button.with_label (_("Record Screen"));
            record_btn.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
            record_btn.can_default = true;
            record_btn.hexpand = true;

            stop_btn = new Gtk.Button.with_label (_("Stop Recording"));
            stop_btn.get_style_context ().add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
            stop_btn.hexpand = true;

            record_btn.tooltip_markup = Granite.markup_accel_tooltip ({"<Ctrl><Shift>R"}, "Toggle recording");
            stop_btn.tooltip_markup = record_btn.tooltip_markup;

            this.set_default (record_btn);

            actions = new Gtk.ButtonBox (Gtk.Orientation.HORIZONTAL);
            actions.halign = Gtk.Align.CENTER;
            actions.margin_top = 24;
            actions.margin_bottom = 12;
            actions.spacing = 6;
            actions.hexpand_set = true;
            actions.hexpand = true;
            actions.set_layout (Gtk.ButtonBoxStyle.EXPAND);
            actions.add (record_btn);

            grid = new Gtk.Grid ();
            grid.margin = 6;
            grid.margin_top = 0;
            grid.row_spacing = 6;
            grid.column_spacing = 12;
            grid.attach (radio_grid     , 0, 0, 2, 1);
            grid.attach (pointer_label  , 0, 1, 1, 1);
            grid.attach (pointer_switch , 1, 1, 1, 1);
            grid.attach (borders_label  , 0, 2, 1, 1);
            grid.attach (borders_switch , 1, 2, 1, 1);
            grid.attach (delay_label    , 0, 3, 1, 1);
            grid.attach (delay_spin     , 1, 3, 1, 1);
            grid.attach (framerate_label, 0, 4, 1, 1);
            grid.attach (framerate_spin , 1, 4, 1, 1);
            grid.attach (format_label, 0, 5, 1, 1);
            grid.attach (format_cmb, 1, 5, 1, 1);

            var mode_switch = new Granite.ModeSwitch.from_icon_name ("display-brightness-symbolic", "weather-clear-night-symbolic");
            mode_switch.primary_icon_tooltip_text = ("Light background");
            mode_switch.secondary_icon_tooltip_text = ("Dark background");

            var titlebar = new Gtk.HeaderBar ();
            titlebar.title = _("Screen Recorder");
            titlebar.show_close_button = true;
            titlebar.has_subtitle = false;
            titlebar.pack_end (mode_switch);
            
            var titlebar_style_context = titlebar.get_style_context ();
            titlebar_style_context.add_class (Gtk.STYLE_CLASS_FLAT);
            //titlebar_style_context.add_class ("default-decoration");

            set_titlebar (titlebar);

            var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            vbox.add (grid);
            vbox.add (actions);

            add (vbox);

            var gtk_settings = Gtk.Settings.get_default ();
            mode_switch.bind_property ("active", gtk_settings, "gtk_application_prefer_dark_theme");

            settings.bind ("dark-theme", mode_switch, "active", GLib.SettingsBindFlags.DEFAULT);
            settings.bind ("mouse-pointer", pointer_switch, "active", GLib.SettingsBindFlags.DEFAULT);
            settings.bind ("show-borders", borders_switch, "active", GLib.SettingsBindFlags.DEFAULT);
            settings.bind ("delay", delay_spin, "value", GLib.SettingsBindFlags.DEFAULT);
            settings.bind ("framerate", framerate_spin, "value", GLib.SettingsBindFlags.DEFAULT);
            delay = delay_spin.get_value_as_int () * 1000;
            framerate = framerate_spin.get_value_as_int ();

            format_cmb.changed.connect (() => {
                settings.set_string ("format", format_cmb.get_active_text ());
            });

            if (settings.get_enum ("last-capture-mode") == CaptureType.AREA){
                capture_mode = CaptureType.AREA;
                selection.active = true;
            }

            delay_spin.value_changed.connect (() => {
                delay = delay_spin.get_value_as_int () * 1000;
            });

            framerate_spin.value_changed.connect (() => {
                framerate = framerate_spin.get_value_as_int ();
            });

            all.toggled.connect (() => {
                capture_mode = CaptureType.SCREEN;
                settings.set_enum ("last-capture-mode", capture_mode);
            });

            selection.toggled.connect (() => {
                capture_mode = CaptureType.AREA;
                settings.set_enum ("last-capture-mode", capture_mode);
            });

            record_btn.clicked.connect (() => {
                switch (capture_mode) {
                    case CaptureType.SCREEN:
                        capture_screen ();
                        break;
                    case CaptureType.AREA:
                        capture_area ();
                        break;
                }
            });
            stop_btn.clicked.connect (stop_recording);
            KeybindingManager manager = new KeybindingManager();
            manager.bind("<Ctrl><Shift>R", () => {
                if (recording) {
                    stop_recording ();
                } else {
                    record_btn.clicked ();
                }
            });
        }
        
        void capture_screen () {
            Timeout.add (delay, () => {
                start_recording (null);
                return false;
            });
        }

        void capture_area () {
            var selection_area = new Screenshot.Widgets.SelectionArea ();
            selection_area.show_all ();

            selection_area.cancelled.connect (() => {
                selection_area.close ();
            });

            var win = selection_area.get_window ();

            selection_area.captured.connect (() => {
                selection_area.close ();
                Timeout.add (delay, () => {
                    start_recording (win);
                    return false;
                });
            });
        }

        void start_recording (Gdk.Window? win) {
            if (win == null) {
                win = Gdk.get_default_root_window ();
            }

            Gdk.Rectangle selection_rect;
            win.get_frame_extents (out selection_rect);
            var temp_dir = Environment.get_tmp_dir ();
            tmpfilepath = Path.build_filename (temp_dir, "screenrecorder-%08x.%s".printf (Random.next_int (), format_cmb.get_active_text ()));
            debug ("Temp file created at: %s", tmpfilepath);

            last_recording_width  = selection_rect.width;
            last_recording_height = selection_rect.height;
            ffmpegwrapper = new FFmpegWrapper (
                tmpfilepath, format_cmb.get_active_text (),
                framerate,
                selection_rect.x,
                selection_rect.y,
                selection_rect.width,
                selection_rect.height,
                pointer_switch.get_state (),
                borders_switch.get_state ()
            );
            grid.set_sensitive (false);
            recording = true;
            actions.remove (record_btn);
            actions.add (stop_btn);
            stop_btn.show ();
        }
        
        void stop_recording () {
            ffmpegwrapper.stop();
            var save_dialog = new SaveDialog (tmpfilepath, this, last_recording_width, last_recording_height);
            save_dialog.show_all ();
            grid.set_sensitive (true);
            recording = false;
            actions.remove (stop_btn);
            actions.add (record_btn);
        }

        string get_default_audio_output () {
            /*-
             * Copyright (c) 2011-2015 Eidete Developers
             * Copyright (c) 2017-2018 Artem Anufrij <artem.anufrij@live.de>
             * https://github.com/artemanufrij/screencast
             */
            string default_output = "";
            try {
                string sound_outputs = "";
                Process.spawn_command_line_sync ("pacmd list-sinks", out sound_outputs);
                GLib.Regex re = new GLib.Regex ("(?<=\\*\\sindex:\\s\\d\\s\\sname:\\s<)[\\w\\.\\-]*");
                MatchInfo mi;
                if (re.match (sound_outputs, 0, out mi)) {
                    default_output = mi.fetch (0);
                }
            } catch (Error e) {
                warning (e.message);
            }
            return default_output;
        }
    }
}