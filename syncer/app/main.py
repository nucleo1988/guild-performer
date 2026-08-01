"""
Guild Performer Sync - simple Windows GUI for non-technical officers.
"""

from __future__ import annotations

import argparse
import sys
import tkinter as tk
from tkinter import filedialog, messagebox, ttk
from pathlib import Path

from sync_core import (
    SyncConfig,
    config_path,
    detect_addon_path,
    run_sync,
)


APP_TITLE = "Guild Performer Sync"
APP_VERSION = "1.1.0"


def set_start_with_windows(enabled: bool, exe_path: Path) -> None:
    """Create/remove HKCU Run key so the app starts minimized with Windows."""
    try:
        import winreg
    except ImportError:
        return

    key_path = r"Software\Microsoft\Windows\CurrentVersion\Run"
    value_name = "GuildPerformerSync"
    with winreg.OpenKey(winreg.HKEY_CURRENT_USER, key_path, 0, winreg.KEY_SET_VALUE) as key:
        if enabled:
            cmd = f'"{exe_path}" --autostart'
            winreg.SetValueEx(key, value_name, 0, winreg.REG_SZ, cmd)
        else:
            try:
                winreg.DeleteValue(key, value_name)
            except FileNotFoundError:
                pass


class SyncApp(tk.Tk):
    def __init__(self, start_minimized: bool = False):
        super().__init__()
        self.title(f"{APP_TITLE} {APP_VERSION}")
        self.minsize(560, 480)
        self.geometry("640x520")
        self.configure(bg="#1a1d24")

        self.cfg = SyncConfig.load(config_path())
        if not self.cfg.addon_path:
            found = detect_addon_path()
            if found:
                self.cfg.addon_path = found

        self._timer_id: str | None = None
        self._build_ui()
        self._load_into_form()
        self.protocol("WM_DELETE_WINDOW", self._on_close)

        if start_minimized:
            self.after(200, self.iconify)
        if self.cfg.auto_enabled:
            self.after(800, self._tick_auto)
            self.after(1500, lambda: self._do_sync(silent=True))

    def _build_ui(self) -> None:
        style = ttk.Style(self)
        try:
            style.theme_use("clam")
        except tk.TclError:
            pass
        style.configure("TFrame", background="#1a1d24")
        style.configure("TLabel", background="#1a1d24", foreground="#e8eaed", font=("Segoe UI", 10))
        style.configure("Header.TLabel", background="#1a1d24", foreground="#7ec8ff", font=("Segoe UI Semibold", 16))
        style.configure("Hint.TLabel", background="#1a1d24", foreground="#9aa0ac", font=("Segoe UI", 9))
        style.configure("TButton", font=("Segoe UI", 10))
        style.configure("TCheckbutton", background="#1a1d24", foreground="#e8eaed", font=("Segoe UI", 10))
        style.configure("TEntry", fieldbackground="#2a2f3a", foreground="#ffffff")

        root = ttk.Frame(self, padding=16)
        root.pack(fill=tk.BOTH, expand=True)

        ttk.Label(root, text=APP_TITLE, style="Header.TLabel").pack(anchor="w")
        ttk.Label(
            root,
            text="Aggiorna il roster Guild Performer dal sito, senza usare PowerShell.",
            style="Hint.TLabel",
        ).pack(anchor="w", pady=(0, 12))

        # URL
        ttk.Label(root, text="1. URL sync della gilda (dal sito > Config > Copia URL)").pack(anchor="w")
        self.url_var = tk.StringVar()
        url_row = ttk.Frame(root)
        url_row.pack(fill=tk.X, pady=(4, 10))
        self.url_entry = ttk.Entry(url_row, textvariable=self.url_var)
        self.url_entry.pack(side=tk.LEFT, fill=tk.X, expand=True)
        ttk.Button(url_row, text="Incolla", width=10, command=self._paste_url).pack(side=tk.LEFT, padx=(8, 0))

        # Path
        ttk.Label(root, text="2. Cartella addon GuildPerformer").pack(anchor="w")
        path_row = ttk.Frame(root)
        path_row.pack(fill=tk.X, pady=(4, 10))
        self.path_var = tk.StringVar()
        ttk.Entry(path_row, textvariable=self.path_var).pack(side=tk.LEFT, fill=tk.X, expand=True)
        ttk.Button(path_row, text="Sfoglia…", width=10, command=self._browse).pack(side=tk.LEFT, padx=(8, 4))
        ttk.Button(path_row, text="Trova", width=8, command=self._autodetect).pack(side=tk.LEFT)

        # Options
        opts = ttk.Frame(root)
        opts.pack(fill=tk.X, pady=(4, 8))
        self.auto_var = tk.BooleanVar()
        self.startup_var = tk.BooleanVar()
        ttk.Checkbutton(opts, text="Sincronizza automaticamente ogni", variable=self.auto_var).pack(side=tk.LEFT)
        self.minutes_var = tk.StringVar(value="30")
        ttk.Spinbox(opts, from_=5, to=1440, width=5, textvariable=self.minutes_var).pack(side=tk.LEFT, padx=6)
        ttk.Label(opts, text="minuti").pack(side=tk.LEFT)
        ttk.Checkbutton(
            root,
            text="Avvia con Windows (in background)",
            variable=self.startup_var,
        ).pack(anchor="w", pady=(0, 10))

        # Buttons
        btn_row = ttk.Frame(root)
        btn_row.pack(fill=tk.X, pady=(0, 10))
        ttk.Button(btn_row, text="Salva impostazioni", command=self._save).pack(side=tk.LEFT)
        ttk.Button(btn_row, text="Sincronizza ora", command=lambda: self._do_sync(force=True)).pack(
            side=tk.LEFT, padx=8
        )

        ttk.Label(
            root,
            text="Dopo il sync: in World of Warcraft digita  /reload  oppure  /gp sync",
            style="Hint.TLabel",
        ).pack(anchor="w", pady=(0, 8))

        # Log
        ttk.Label(root, text="Stato").pack(anchor="w")
        self.log = tk.Text(
            root,
            height=10,
            wrap=tk.WORD,
            bg="#12151b",
            fg="#d7dbe3",
            insertbackground="#fff",
            relief=tk.FLAT,
            font=("Consolas", 9),
        )
        self.log.pack(fill=tk.BOTH, expand=True, pady=(4, 0))
        self._log("Pronto. Incolla l'URL della gilda e premi Sincronizza ora.")

    def _log(self, msg: str) -> None:
        self.log.insert(tk.END, msg.rstrip() + "\n")
        self.log.see(tk.END)

    def _load_into_form(self) -> None:
        self.url_var.set(self.cfg.url)
        self.path_var.set(self.cfg.addon_path)
        self.auto_var.set(self.cfg.auto_enabled)
        self.minutes_var.set(str(self.cfg.auto_minutes or 30))
        self.startup_var.set(self.cfg.start_with_windows)

    def _read_form(self) -> SyncConfig:
        try:
            mins = int(self.minutes_var.get())
        except ValueError:
            mins = 30
        return SyncConfig(
            url=self.url_var.get().strip(),
            addon_path=self.path_var.get().strip(),
            format="lua",
            auto_minutes=max(5, mins),
            auto_enabled=bool(self.auto_var.get()),
            start_with_windows=bool(self.startup_var.get()),
        )

    def _paste_url(self) -> None:
        try:
            text = self.clipboard_get().strip()
        except tk.TclError:
            return
        if text:
            self.url_var.set(text)

    def _browse(self) -> None:
        initial = self.path_var.get() or r"C:\Program Files (x86)\World of Warcraft\_retail_\Interface\AddOns"
        chosen = filedialog.askdirectory(title="Seleziona cartella GuildPerformer", initialdir=initial)
        if chosen:
            self.path_var.set(chosen)

    def _autodetect(self) -> None:
        found = detect_addon_path()
        if found:
            self.path_var.set(found)
            self._log(f"Trovato: {found}")
        else:
            messagebox.showwarning(
                APP_TITLE,
                "Addon non trovato automaticamente.\n"
                "Installa Guild Performer e usa «Sfoglia…» per selezionare la cartella.",
            )

    def _save(self) -> None:
        self.cfg = self._read_form()
        self.cfg.save(config_path())
        exe = Path(sys.executable)
        # When frozen by PyInstaller, sys.executable is the .exe
        set_start_with_windows(self.cfg.start_with_windows, exe)
        self._schedule_timer()
        self._log("Impostazioni salvate.")
        messagebox.showinfo(APP_TITLE, "Impostazioni salvate.")

    def _do_sync(self, force: bool = False, silent: bool = False) -> None:
        self.cfg = self._read_form()
        self.cfg.save(config_path())
        self._log("Sincronizzazione in corso…")
        self.update_idletasks()
        result = run_sync(self.cfg, force=force)
        self._log(result.message)
        if not silent:
            if result.ok:
                messagebox.showinfo(APP_TITLE, result.message)
            else:
                messagebox.showerror(APP_TITLE, result.message)

    def _schedule_timer(self) -> None:
        if self._timer_id is not None:
            self.after_cancel(self._timer_id)
            self._timer_id = None
        if self.cfg.auto_enabled:
            ms = max(5, self.cfg.auto_minutes) * 60 * 1000
            self._timer_id = self.after(ms, self._tick_auto)

    def _tick_auto(self) -> None:
        self._do_sync(force=False, silent=True)
        self._schedule_timer()

    def _on_close(self) -> None:
        # Keep running minimized if auto-sync is on (optional: just close)
        self.destroy()


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=APP_TITLE)
    parser.add_argument("--sync", action="store_true", help="Sync once (no GUI) and exit")
    parser.add_argument("--force", action="store_true", help="Force sync even if unchanged")
    parser.add_argument("--autostart", action="store_true", help="Start minimized (Windows startup)")
    args = parser.parse_args(argv)

    if args.sync:
        cfg = SyncConfig.load(config_path())
        result = run_sync(cfg, force=args.force)
        try:
            print(result.message)
        except UnicodeEncodeError:
            print(result.message.encode("ascii", "replace").decode("ascii"))
        return 0 if result.ok else 1

    app = SyncApp(start_minimized=args.autostart)
    app.mainloop()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
