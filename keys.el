;;; $DOOMDIR/keys.el -*- lexical-binding: t; -*-
;;; Neovim (LazyVim + ~/.config/nvim) keybindings on top of Doom's defaults.
;;; Doom bindings that already match LazyVim are left alone; only differences
;;; are (re)bound here. Loaded from config.el.

;;; ── Helpers ──────────────────────────────────────────────────────────────

(defun +my/window-or-herdr (dir)
  "Select the window in DIR; at an edge, focus the adjacent herdr pane.
Mirrors nav_or_herdr in nvim's keymaps.lua (only meaningful in a terminal).
Reaches `no-other-window' windows too (treemacs sets it, so windmove would
otherwise skip the tree and fall through to herdr)."
  (condition-case nil
      (let ((windmove-allow-all-windows t))
        (windmove-do-window-select dir))
    (user-error
     (when (and (not (display-graphic-p)) (executable-find "herdr"))
       (call-process "herdr" nil 0 nil
                     "pane" "focus" "--direction" (symbol-name dir))))))

(defun +my/buffer-prev ()
  "Previous buffer, in tab-bar order when centaur-tabs is on (bufferline)."
  (interactive)
  (if (bound-and-true-p centaur-tabs-mode) (centaur-tabs-backward) (previous-buffer)))

(defun +my/buffer-next ()
  "Next buffer, in tab-bar order when centaur-tabs is on (bufferline)."
  (interactive)
  (if (bound-and-true-p centaur-tabs-mode) (centaur-tabs-forward) (next-buffer)))

(defun +my/move-lines (n)
  "Move the current line, or the lines of the visual selection, N lines.
Like LazyVim's <A-j>/<A-k>: reindents and keeps the selection."
  (let* ((visual (evil-visual-state-p))
         (type (and visual (evil-visual-type)))
         (range (and visual (evil-visual-range)))
         (rb (if visual (evil-range-beginning range) (point)))
         (re (if visual (evil-range-end range) (point)))
         (beg (save-excursion (goto-char rb) (line-beginning-position)))
         (end (save-excursion
                (goto-char re)
                ;; a linewise region ends at the bol of the following line
                (when (and visual (> re rb) (bolp)) (backward-char))
                (line-end-position)))
         (line-off (- (line-number-at-pos) (line-number-at-pos beg)))
         (col (current-column))
         (text (buffer-substring beg end)))
    (dotimes (_ (abs n))
      (if (> n 0)
          (when (< (1+ end) (point-max))
            (let* ((nb (1+ end))
                   (ne (save-excursion (goto-char nb) (line-end-position)))
                   (next (buffer-substring nb ne)))
              (delete-region beg ne)
              (goto-char beg)
              (insert next "\n" text)
              (setq beg (+ beg (length next) 1)
                    end (+ beg (length text)))))
        (when (> beg (point-min))
          (let* ((pb (save-excursion (goto-char (1- beg)) (line-beginning-position)))
                 (prev (buffer-substring pb (1- beg))))
            (delete-region pb end)
            (goto-char pb)
            (insert text "\n" prev)
            (setq beg pb
                  end (+ pb (length text)))))))
    (indent-region beg end)
    (setq end (save-excursion (goto-char beg)
                              (forward-line (1- (count-lines beg (max beg end))))
                              (line-end-position)))
    (goto-char beg)
    (forward-line line-off)
    (move-to-column col)
    (when visual
      (evil-visual-select beg end type))))

(defun +my/move-lines-down (count)
  (interactive "p")
  (+my/move-lines count))

(defun +my/move-lines-up (count)
  (interactive "p")
  (+my/move-lines (- count)))

(defun +my/save-and-normal ()
  "Save, then return to normal state (LazyVim <C-s> in every mode)."
  (interactive)
  (save-buffer)
  (evil-normal-state))

(defun +my/format ()
  "Format like conform.nvim (apheleia/LSP); in org, realign tables instead."
  (interactive)
  (if (derived-mode-p 'org-mode)
      (+my/org-format-tables)
    (call-interactively #'+format/region-or-buffer)))

(defun +my/toggle-autoformat (&optional global)
  "LazyVim <leader>uf / uF: toggle format-on-save for the buffer or globally."
  (interactive)
  (if global
      (apheleia-global-mode 'toggle)
    (apheleia-mode 'toggle))
  (message "Autoformat (%s): %s" (if global "global" "buffer")
           (if (if global apheleia-global-mode apheleia-mode) "on" "off")))

(defun +my/toggle-background ()
  "LazyVim <leader>ub: switch between the dark and light theme."
  (interactive)
  (load-theme (if (eq doom-theme +my/dark-theme) +my/light-theme +my/dark-theme) t))

(defun +my/toggle-conceal ()
  "LazyVim <leader>uc: show/hide markup (emphasis markers, links)."
  (interactive)
  (cond ((derived-mode-p 'org-mode)
         (setq-local org-hide-emphasis-markers (not org-hide-emphasis-markers))
         (org-toggle-link-display)
         (font-lock-flush))
        ((derived-mode-p 'markdown-mode) (markdown-toggle-markup-hiding))
        (t (user-error "Nothing to conceal here"))))

(defun +my/toggle-render ()
  "LazyVim <leader>um (render-markdown): toggle the rendered view."
  (interactive)
  (cond ((derived-mode-p 'org-mode)
         (org-modern-mode 'toggle)
         (+my/org-mermaid-preview-mode 'toggle))
        ((derived-mode-p 'markdown-mode) (markdown-toggle-markup-hiding))
        (t (user-error "Not an org/markdown buffer"))))

(defun +my/kill-buffers-beside (side)
  "Kill tab-bar buffers to the left/right of this one (bufferline bl / br)."
  (let* ((tabs (mapcar #'centaur-tabs-tab-value (centaur-tabs-tabs (centaur-tabs-current-tabset t))))
         (pos (cl-position (current-buffer) tabs)))
    (when pos
      (mapc #'kill-buffer (if (eq side 'left)
                              (cl-subseq tabs 0 pos)
                            (cl-subseq tabs (1+ pos)))))))

(defun +my/search-word-cwd ()
  "LazyVim <leader>sW: grep the word at point from the current directory."
  (interactive)
  (consult-ripgrep default-directory (thing-at-point 'symbol t)))

(defun +my/quickfix ()
  "Show the quickfix equivalent: the last grep/compile/xref results buffer."
  (interactive)
  (if (buffer-live-p next-error-last-buffer)
      (pop-to-buffer next-error-last-buffer)
    (user-error "No quickfix-style results yet")))

(defun +my/explore-org ()
  "<leader>fo: explorer rooted at `org-directory' (~/org)."
  (interactive)
  (dired org-directory))

(defmacro +my/in-org (org-def &optional fallback)
  "Leader binding that runs ORG-DEF in org buffers and FALLBACK elsewhere.
Doom's leader map is global, so nvim-orgmode's buffer-local <leader>o keys
have to dispatch on the mode instead."
  `(general-predicate-dispatch ,fallback
     (derived-mode-p 'org-mode) ,org-def))

(defun +my/toggle-relative-numbers ()
  (interactive)
  (setq-local display-line-numbers
              (if (eq display-line-numbers 'relative) t 'relative)))

(defun +my/window-zoom ()
  "Toggle maximizing the current window (LazyVim <leader>wm)."
  (interactive)
  (if (one-window-p) (winner-undo) (doom/window-maximize-buffer)))

(defun +my/dap-continue ()
  "Continue the debug session, or start one (nvim-dap's <F5>)."
  (interactive)
  (if (and (fboundp 'dape--live-connection) (dape--live-connection 'parent t))
      (call-interactively #'dape-continue)
    (call-interactively #'dape)))

(defun +my/diagnostic-next (count level)
  "Jump COUNT flycheck diagnostics of at least LEVEL (LazyVim ]e / ]w)."
  (let ((flycheck-navigation-minimum-level level))
    (flycheck-next-error count)))

(defun +my/comment-open (below)
  "Open a commented line BELOW (or above) the current one (LazyVim gco/gcO)."
  (if below (evil-open-below 1) (evil-open-above 1))
  (insert (string-trim-right comment-start) " ")
  (unless (string-empty-p comment-end)
    (save-excursion (insert " " (string-trim-left comment-end)))))

(defun +my/search-todos ()
  "Grep the project for TODO-style keywords (LazyVim <leader>st)."
  (interactive)
  (consult-ripgrep (doom-project-root) "\\b(TODO|FIXME|FIX|HACK|NOTE|BUG|PERF|WARN)\\b"))

(defun +my/redraw ()
  "Clear search highlight and redraw (LazyVim <leader>ur)."
  (interactive)
  (evil-ex-nohighlight)
  (redraw-display))

(defun +my/workspace-kill-others ()
  "Kill every workspace but the current one (LazyVim <leader><tab>o)."
  (interactive)
  (dolist (name (+workspace-list-names))
    (unless (equal name (+workspace-current-name))
      (+workspace-kill name))))

(defun +my/compilation-buffer ()
  "Show the last compilation/task output (overseer's task list)."
  (interactive)
  (if-let* ((buf (get-buffer "*compilation*")))
      (pop-to-buffer buf)
    (user-error "No task has run yet")))


;; nvim-orgmode's multi-key <leader>o groups (i…, n…, b…, d…).
(defvar +my/org-insert-map
  (define-keymap
    "d" #'org-deadline
    "s" #'org-schedule
    "." #'org-time-stamp
    "!" #'org-time-stamp-inactive
    "h" #'org-insert-heading-respect-content
    "T" #'org-insert-todo-heading
    "t" #'org-insert-todo-heading-respect-content))
(defvar +my/org-note-map (define-keymap "a" #'org-add-note))
(defvar +my/org-babel-map (define-keymap "t" #'org-babel-tangle))
(defvar +my/org-date-map (define-keymap "!" #'org-toggle-timestamp-type))


;;; ── Editing / motions ────────────────────────────────────────────────────

;; flash.nvim: s = jump anywhere, S = structural selection.
;; Doom turns evil-snipe-mode on from `doom-first-input-hook', i.e. after any
;; `after!' block, so it has to be unhooked or it keeps s/S. The override mode
;; (smarter f/t/F/T + ; and ,) stays, like flash's enhanced f/t.
(remove-hook 'doom-first-input-hook #'evil-snipe-mode)
(map! :nvo "s" #'evil-avy-goto-char-timer
      :nv  "S" #'er/expand-region)
;; evil-surround claims visual S in its own minor-mode map; gsa covers it.
(map! :after evil-surround
      :map evil-surround-mode-map
      :v "S" #'er/expand-region)

;; <C-space>: treesitter incremental selection, <BS> shrinks it back.
;; Doom's corfu config claims n/v C-SPC in `corfu-mode-map'; insert-state
;; C-SPC (complete) is left alone, as in LazyVim.
(map! :n "C-SPC" #'er/expand-region
      :v "C-SPC" #'er/expand-region
      :v "DEL"   #'er/contract-region)
(map! :after corfu
      :map corfu-mode-map
      :n "C-SPC" #'er/expand-region
      :v "C-SPC" #'er/expand-region)

;; gco / gcO: add a comment below / above.
(map! :n "gco" (cmd! (+my/comment-open t))
      :n "gcO" (cmd! (+my/comment-open nil)))

;; mini.surround's gs* keys (ys/cs/ds from evil-surround still work).
;; Doom's easymotion keys under gs stay available alongside these.
(map! :n "gsa" #'evil-surround-region
      :v "gsa" #'evil-surround-region
      :n "gsd" #'evil-surround-delete
      :n "gsr" #'evil-surround-change)

;; Move lines up/down.
(map! :n "M-j" #'+my/move-lines-down
      :n "M-k" #'+my/move-lines-up
      :v "M-j" #'+my/move-lines-down
      :v "M-k" #'+my/move-lines-up
      :i "M-j" (cmd! (evil-normal-state) (+my/move-lines 1) (evil-insert-state))
      :i "M-k" (cmd! (evil-normal-state) (+my/move-lines -1) (evil-insert-state)))

;; Keep the selection after indenting with < / > in visual mode.
(map! :v "<" #'+evil/shift-left
      :v ">" #'+evil/shift-right)

;; <C-s> saves in every mode; <C-c> leaves insert like in vim.
(map! :nvi "C-s" #'+my/save-and-normal
      :i   "C-c" #'evil-normal-state)


;;; ── Buffers, windows, terminal ───────────────────────────────────────────

;; S-h / S-l, [b / ]b: previous/next buffer (bufferline); [B / ]B move it.
(map! :n "H"  #'+my/buffer-prev
      :n "L"  #'+my/buffer-next
      :n "[b" #'+my/buffer-prev
      :n "]b" #'+my/buffer-next
      :n "[B" #'centaur-tabs-move-current-tab-to-left
      :n "]B" #'centaur-tabs-move-current-tab-to-right)

;; <C-h/j/k/l>: move between windows, falling through to herdr panes.
;; In the override map so it also works in magit, dired, help buffers...
(map! :map general-override-mode-map
      :nm "C-h" (cmd! (+my/window-or-herdr 'left))
      :nm "C-j" (cmd! (+my/window-or-herdr 'down))
      :nm "C-k" (cmd! (+my/window-or-herdr 'up))
      :nm "C-l" (cmd! (+my/window-or-herdr 'right)))
(after! treemacs-evil
  (map! :map evil-treemacs-state-map
        "C-h" (cmd! (+my/window-or-herdr 'left))
        "C-l" (cmd! (+my/window-or-herdr 'right))))

;; <C-arrows>: resize windows.
(map! :n "C-<up>"    #'evil-window-increase-height
      :n "C-<down>"  #'evil-window-decrease-height
      :n "C-<left>"  #'evil-window-decrease-width
      :n "C-<right>" #'evil-window-increase-width)

;; <C-'>: this project's Claude Code (ide.el), from anywhere.
(map! :nvi "C-'" #'+my/claude-toggle)
(after! vterm
  (map! :map vterm-mode-map "C-'" #'+my/claude-toggle))

;; <C-/>: toggle the terminal from anywhere (insert/terminal included).
(map! :nvi "C-/" #'+vterm/toggle
      :nvi "C-_" #'+vterm/toggle)
(after! vterm
  (map! :map vterm-mode-map
        "C-/" #'+vterm/toggle
        "C-_" #'+vterm/toggle))


;;; ── LSP / diagnostics (lsp-mode buffers) ─────────────────────────────────

(map! :n  "gr" #'+lookup/references      ; Doom: eval operator
      :n  "gy" #'+lookup/type-definition ; Doom: yank unindented
      :n  "gI" #'+lookup/implementations
      :n  "]d" #'flycheck-next-error     ; Doom: next git hunk
      :n  "[d" #'flycheck-previous-error
      :n  "]e" (cmd! (+my/diagnostic-next 1 'error))
      :n  "[e" (cmd! (+my/diagnostic-next -1 'error))
      :n  "]w" (cmd! (+my/diagnostic-next 1 'warning))   ; Doom: next workspace
      :n  "[w" (cmd! (+my/diagnostic-next -1 'warning))  ; (now <leader><tab>])
      :n  "]q" #'next-error              ; quickfix = grep/compile results
      :n  "[q" #'previous-error
      :nm "]h" #'+vc-gutter/next-hunk    ; Doom: next outline heading
      :nm "[h" #'+vc-gutter/previous-hunk)

;; org.nvim's global keys.
(map! "C-c a" #'org-agenda
      "C-c c" #'org-capture
      "C-c l" #'org-store-link)

(map! :after lsp-mode
      :map lsp-mode-map
      :n "gD" #'lsp-find-declaration     ; Doom: references (now gr)
      :n "gK" #'lsp-signature-activate
      :i "C-k" #'lsp-signature-activate)


;;; ── Debugger (keys from nvim's dap.lua, on dape) ─────────────────────────

(map! "<f5>"    #'+my/dap-continue
      "<f10>"   #'dape-next
      "<C-f10>" #'dape-until
      "<f11>"   #'dape-step-in
      "<S-f11>" #'dape-step-out)


;;; ── Leader ───────────────────────────────────────────────────────────────
;;
;; IMPORTANT: `(:prefix ("b" . "desc") ...)' binds the prefix to a *fresh*
;; keymap and wipes everything Doom had under it (SPC w v, SPC c a, SPC g g...
;; all vanished that way). To add keys to a prefix Doom already defines, use
;; the plain `(:prefix "b" ...)' form; keep `("x" . "desc")' for new prefixes.

;; Doom binds these to single commands; free them so they can be prefixes.
;; (n is Doom's notes prefix; LazyVim uses it for notification history.)
(map! :leader "x" nil "u" nil "n" nil "a" nil)

;; SPC w: C-w plus LazyVim's zoom and vimwiki's global keys. A child keymap of
;; `evil-window-map', so the additions don't leak into C-w itself.
(after! evil
  (defvar +my/leader-window-map
    (let ((map (make-sparse-keymap)))
      (set-keymap-parent map evil-window-map)
      map))
  (map! :map +my/leader-window-map
        :desc "Toggle zoom"              "m" #'+my/window-zoom
        :desc "Wiki index"               "w" #'+my/vimwiki-index
        :desc "Wiki index (new tab)"     "t" #'+my/vimwiki-index-tab
        :desc "Wiki select"              "s" #'+my/vimwiki-index
        :desc "Diary index"              "i" #'+my/vimwiki-diary-index
        ;; vimwiki's page keys, only inside wiki buffers
        :desc "Delete window / wiki page" "d"
        (general-predicate-dispatch #'evil-window-delete
          (bound-and-true-p +my/vimwiki-mode) #'doom/delete-this-file)
        :desc "Rotate / rename wiki page" "r"
        (general-predicate-dispatch #'evil-window-rotate-downwards
          (bound-and-true-p +my/vimwiki-mode) #'doom/move-this-file)
        (:prefix ("SPC" . "diary")
         :desc "Today"                   "w" (cmd! (find-file (+my/vimwiki-diary-file)))
         :desc "Today (new tab)"         "t" (cmd! (+workspace/new) (find-file (+my/vimwiki-diary-file)))
         :desc "Yesterday"               "y" (cmd! (find-file (+my/vimwiki-diary-file -1)))
         :desc "Tomorrow"                "m" (cmd! (find-file (+my/vimwiki-diary-file 1)))
         :desc "Generate diary links"    "i" #'+my/vimwiki-diary-generate-links))
  (map! :leader :desc "windows" "w" +my/leader-window-map))

(map! :leader
      :desc "Explorer (treemacs)"      "e"  #'+treemacs/toggle
      :desc "Explorer: reveal file"    "E"  #'treemacs-find-file
      :desc "Toggle scratch buffer"    "."  #'doom/toggle-scratch-buffer
      :desc "Select scratch buffer"    "S"  #'doom/switch-to-scratch-buffer
      :desc "Buffer keymaps"           "?"  #'which-key-show-major-mode
      :desc "Split window below"       "-"  #'evil-window-split
      :desc "Split window right"       "|"  #'evil-window-vsplit
      :desc "Universal argument"       "U"  #'universal-argument
      :desc "Command history"          ":"  #'evil-command-window-ex
      :desc "Keywordprg (docs)"        "K"  #'+lookup/documentation
      :desc "Notification history"     "n"  #'view-echo-area-messages
      :desc "Send selection to Claude" "ai" #'claude-code-ide-insert-at-mentioned
      :desc "Claude (this project)"    "ac" #'+my/claude-toggle
      :desc "Claude: another instance" "aC" #'+my/claude-new
      :desc "Claude: all sessions"     "al" #'claude-code-ide-list-sessions
      :desc "Claude: continue last"    "ar" #'claude-code-ide-continue
      :desc "Claude: resume…"          "aR" #'claude-code-ide-resume
      :desc "Claude: stop"             "aq" #'claude-code-ide-stop
      :desc "Claude: menu"             "am" #'claude-code-ide-menu
      :desc "Org: meta return / bookmark" "RET" (+my/in-org #'org-meta-return #'bookmark-jump)

      (:prefix "b"
       :desc "Switch to other buffer"   "b" #'evil-switch-to-windows-last-buffer
       :desc "Delete buffer and window" "D" #'kill-buffer-and-window
       :desc "Pick buffer"              "j" #'centaur-tabs-ace-jump
       :desc "Delete buffers to the left"  "l" (cmd! (+my/kill-buffers-beside 'left))
       :desc "Delete buffers to the right" "r" (cmd! (+my/kill-buffers-beside 'right))
       :desc "Delete other buffers"     "o" #'doom/kill-other-buffers)


      (:prefix "TAB"
       :desc "New workspace"            "TAB" #'+workspace/new
       :desc "First workspace"          "f"   #'+workspace/switch-to-0
       :desc "Last workspace"           "l"   #'+workspace/switch-to-final
       :desc "Close other workspaces"   "o"   #'+my/workspace-kill-others
       :desc "Load workspace from file" "L"   #'+workspace/load)

      (:prefix "f"
       :desc "Explorer (treemacs)"      "e" #'+treemacs/toggle
       :desc "Explorer: reveal file"    "E" #'treemacs-find-file
       :desc "Explorer (~/org)"         "o" #'+my/explore-org
       :desc "Find file (project root)" "f" #'projectile-find-file
       :desc "Find file (cwd)"          "F" #'+default/find-file-under-here
       :desc "Buffers"                  "b" #'consult-buffer
       :desc "Find config file"         "c" #'doom/find-file-in-private-config
       :desc "Git files"                "g" #'projectile-find-file
       :desc "New file"                 "n" #'evil-buffer-new
       :desc "Projects"                 "p" #'projectile-switch-project
       :desc "Recent files (project)"   "R" #'projectile-recentf
       :desc "Terminal (popup)"         "t" #'+vterm/toggle
       :desc "Terminal (here)"          "T" #'+vterm/here)

      (:prefix "s"
       :desc "Registers"                "\"" #'consult-register
       :desc "Grep open buffers"        "B" #'consult-line-multi
       :desc "Icons"                    "i" #'nerd-icons-insert
       :desc "Jumps"                    "j" #'evil-show-jumps
       :desc "Location list"            "l" #'flycheck-list-errors
       :desc "Quickfix list"            "q" #'+my/quickfix
       :desc "Word (cwd)"               "W" #'+my/search-word-cwd
       :desc "Command history"          "c" #'consult-complex-command
       :desc "Commands"                 "C" #'execute-extended-command
       :desc "Diagnostics (project)"    "d" #'consult-flycheck
       :desc "Diagnostics (buffer)"     "D" #'flycheck-list-errors
       :desc "Grep (project root)"      "g" #'+default/search-project
       :desc "Grep (cwd)"               "G" #'+default/search-cwd
       :desc "Help"                     "h" #'describe-symbol
       :desc "Highlights (faces)"       "H" #'list-faces-display
       :desc "Keymaps"                  "k" #'embark-bindings
       :desc "Marks"                    "m" #'evil-show-marks
       :desc "Man pages"                "M" #'man
       :desc "Search & replace"         "r" #'projectile-replace-regexp
       :desc "Resume last search"       "R" #'vertico-repeat
       :desc "LSP symbols (buffer)"     "s" #'consult-lsp-file-symbols
       :desc "LSP symbols (workspace)"  "S" #'consult-lsp-symbols
       :desc "Todo"                     "t" #'+my/search-todos
       :desc "Undotree"                 "u" #'vundo
       :desc "Word (project root)"      "w" #'+default/search-project-for-symbol-at-point)

      (:prefix "c"
       :desc "Line diagnostics"         "d" #'flycheck-display-error-at-point
       :desc "Format"                   "f" #'+my/format
       :desc "Format injected langs"    "F" #'+my/format
       :desc "Markdown preview"         "p" #'markdown-preview
       :desc "LSP references (tree)"    "S" #'lsp-treemacs-references
       :desc "Install LSP server"       "m" #'lsp-install-server
       :desc "Rename file"              "R" #'doom/move-this-file
       :desc "Roslyn: pick solution"    "P" #'+my/roslyn-switch-solution
       :desc "Symbols outline"          "s" #'lsp-treemacs-symbols)

      (:prefix "g"
       :desc "Blame"                    "b" #'magit-blame-addition
       :desc "Browse in remote"         "B" #'+vc/git-link
       :desc "Copy remote URL"          "Y" #'git-link
       :desc "Diff (unstaged hunks)"    "d" #'magit-diff-unstaged
       :desc "Diff vs origin"           "D" (cmd! (magit-diff-range (concat (magit-get-upstream-branch) "...")))
       :desc "Status (cwd)"             "G" (cmd! (magit-status-setup-buffer default-directory))
       :desc "Log (all branches)"       "L" #'magit-log-all
       :desc "File history"             "f" #'magit-log-buffer-file
       :desc "Log"                      "l" #'magit-log-current
       :desc "Status"                   "s" #'magit-status
       :desc "Stash"                    "S" #'magit-stash
       (:prefix ("h" . "hunks")
        :desc "Stage hunk"              "s" #'+vc-gutter/stage-hunk
        :desc "Reset hunk"              "r" #'+vc-gutter/save-and-revert-hunk
        :desc "Preview hunk"            "p" #'diff-hl-show-hunk
        :desc "Blame"                   "b" #'magit-blame-addition
        :desc "Blame buffer"            "B" #'magit-blame
        :desc "Diff this ~"             "D" (cmd! (magit-diff-range "HEAD~" nil (list (magit-file-relative-name))))
        :desc "Unstage buffer"          "u" #'magit-file-unstage
        :desc "Stage buffer"            "S" #'magit-file-stage
        :desc "Reset buffer"            "R" #'vc-revert
        :desc "Diff this"               "d" #'magit-diff-buffer-file))

      ;; org.nvim + overseer share <leader>o in nvim; Doom's "open" keys stay.
      (:prefix "o"
       :desc "Org agenda"               "a" #'org-agenda
       :desc "Org capture"              "c" #'org-capture
       :desc "Org: go to heading"       "g" #'consult-org-agenda
       :desc "Org: store link"          "ls" #'org-store-link
       :desc "Org: go to clocked task"  "xj" #'org-clock-goto
       :desc "Org: clock out"           "xo" #'org-clock-out
       :desc "Org: cancel clock"        "xq" #'org-clock-cancel
       :desc "Org: clock in"            "xi" (+my/in-org #'org-clock-in)
       :desc "Org: set effort"          "xe" (+my/in-org #'org-set-effort)
       :desc "Org: insert link"         "li" (+my/in-org #'org-insert-link)
       ;; nvim-orgmode's buffer keys; outside org these keep their global meaning
       :desc "Org: refile / REPL"       "r"
       (general-predicate-dispatch #'+eval/open-repl-other-window
         (bound-and-true-p org-capture-mode) #'org-capture-refile
         (derived-mode-p 'org-mode) #'org-refile)
       :desc "Org: kill capture/src"    "k"
       (general-predicate-dispatch nil
         (bound-and-true-p org-capture-mode) #'org-capture-kill
         (bound-and-true-p org-src-mode) #'org-edit-src-abort)
       :desc "Org: open link / Run task" "o" (+my/in-org #'org-open-at-point #'projectile-run-project)
       :desc "Org: save src / Task list" "w"
       (general-predicate-dispatch #'+my/compilation-buffer
         (bound-and-true-p org-src-mode) #'org-edit-src-save)
       :desc "Org: tags / Terminal"     "t" (+my/in-org #'org-set-tags-command #'+vterm/toggle)
       :desc "Org: archive tag / Agenda" "A" (+my/in-org #'org-toggle-archive-tag #'org-agenda)
       :desc "Org: priority"            "," (+my/in-org #'org-priority)
       :desc "Org: toggle heading"      "*" (+my/in-org #'org-toggle-heading)
       :desc "Org: edit special"        "'" (+my/in-org #'org-edit-special)
       :desc "Org: archive subtree"     "$" (+my/in-org #'org-archive-subtree)
       :desc "Org: move subtree down"   "J" (+my/in-org #'org-move-subtree-down)
       :desc "Org: move subtree up"     "K" (+my/in-org #'org-move-subtree-up)
       :desc "Org: export"              "e" (+my/in-org #'org-export-dispatch)
       :desc "Org: insert…"             "i" (+my/in-org +my/org-insert-map)
       :desc "Org: note…"               "n" (+my/in-org +my/org-note-map)
       :desc "Org: babel… / Browser"    "b" (+my/in-org +my/org-babel-map #'browse-url-of-file)
       :desc "Org: timestamp… / Debug"  "d" (+my/in-org +my/org-date-map #'+debugger/start))

      (:prefix "q"
       :desc "Restore last session"     "l" #'doom/quickload-session
       :desc "Restore session"          "s" #'doom/quickload-session
       :desc "Select session"           "S" #'doom/load-session)

      (:prefix ("u" . "ui/toggle")
       :desc "Tabline"                  "A" #'centaur-tabs-mode
       :desc "Dark/light background"    "b" #'+my/toggle-background
       :desc "Conceal markup"           "c" #'+my/toggle-conceal
       :desc "Autoformat (buffer)"      "f" #'+my/toggle-autoformat
       :desc "Autoformat (global)"      "F" (cmd! (+my/toggle-autoformat t))
       :desc "Indent guides"            "g" #'indent-bars-mode
       :desc "Git signs"                "G" #'diff-hl-mode
       :desc "Render markdown/org"      "m" #'+my/toggle-render
       :desc "Smooth scroll"            "S" #'pixel-scroll-precision-mode
       :desc "Zen mode"                 "z" #'+zen/toggle
       :desc "Colorschemes"             "C" #'consult-theme
       :desc "Diagnostics"              "d" #'flycheck-mode
       :desc "Inlay hints"              "h" #'lsp-inlay-hints-mode
       :desc "Inspect char/face"        "i" #'describe-char
       :desc "Inspect tree"             "I" #'treesit-explore-mode
       :desc "Line numbers"             "l" #'display-line-numbers-mode
       :desc "Relative numbers"         "L" #'+my/toggle-relative-numbers
       :desc "Auto pairs"               "p" #'smartparens-mode
       :desc "Redraw / clear hlsearch"  "r" #'+my/redraw
       :desc "Spelling"                 "s" #'flyspell-mode
       :desc "Syntax highlight"         "T" #'font-lock-mode
       :desc "Word wrap"                "w" #'visual-line-mode
       :desc "Zoom window"              "Z" #'+my/window-zoom
       :desc "Fullscreen"               "F" #'toggle-frame-fullscreen)

      (:prefix ("x" . "diagnostics")
       :desc "Diagnostics (project)"    "x" #'+default/diagnostics
       :desc "Diagnostics (buffer)"     "X" #'flycheck-list-errors
       :desc "Location list"            "l" #'flycheck-list-errors
       :desc "Location list (all)"      "L" #'+default/diagnostics
       :desc "Quickfix list"            "q" #'+my/quickfix
       :desc "Quickfix list (all)"      "Q" #'+my/quickfix
       :desc "Todo (buffer)"            "t" #'hl-todo-occur
       :desc "Todo (project)"           "T" #'+my/search-todos)

      (:prefix ("d" . "debug")
       :desc "Run with args / start"    "a" #'dape
       :desc "Toggle breakpoint"        "b" #'dape-breakpoint-toggle
       :desc "Conditional breakpoint"   "B" #'dape-breakpoint-expression
       :desc "Run/Continue"             "c" #'+my/dap-continue
       :desc "Run to cursor"            "C" #'dape-until
       :desc "Eval expression"          "e" #'dape-evaluate-expression
       :desc "Step into"                "i" #'dape-step-in
       :desc "Step over"                "O" #'dape-next
       :desc "Step out"                 "o" #'dape-step-out
       :desc "Stack down"               "j" #'dape-stack-select-down
       :desc "Stack up"                 "k" #'dape-stack-select-up
       :desc "Run last / restart"       "l" #'dape-restart
       :desc "Pause"                    "P" #'dape-pause
       :desc "REPL"                     "r" #'dape-repl
       :desc "Sessions / info"          "s" #'dape-info
       :desc "Terminate"                "t" #'dape-kill
       :desc "Toggle UI"                "u" #'dape-info
       :desc "Watch / hover value"      "w" #'dape-watch-dwim
       :desc "Remove all breakpoints"   "X" #'dape-breakpoint-remove-all
       (:prefix ("p" . "profiler")
        :desc "Toggle profiler"         "p" (cmd! (if (profiler-running-p)
                                                     (progn (profiler-stop) (profiler-report))
                                                   (profiler-start 'cpu+mem)))
        :desc "Profiler report"         "s" #'profiler-report)))


;;; ── More LazyVim motions ─────────────────────────────────────────────────

;; n / N always search forward / backward, whatever direction started it.
(evil-define-motion +my/search-next (count)
  :jump t :type exclusive
  (if (eq evil-ex-search-direction 'backward)
      (evil-ex-search-previous count)
    (evil-ex-search-next count)))
(evil-define-motion +my/search-prev (count)
  :jump t :type exclusive
  (if (eq evil-ex-search-direction 'backward)
      (evil-ex-search-next count)
    (evil-ex-search-previous count)))

(map! :nmv "n" #'+my/search-next
      :nmv "N" #'+my/search-prev
      ;; todo-comments
      :nm "]t" #'hl-todo-next
      :nm "[t" #'hl-todo-previous
      ;; treesitter-textobjects function starts/ends
      :nm "]f" (cmd! (beginning-of-defun -1))
      :nm "[f" #'beginning-of-defun
      :nm "]F" #'end-of-defun
      :nm "[F" (cmd! (end-of-defun -1)))


;;; ── Ex commands from nvim plugins ────────────────────────────────────────

;; diffview.nvim
(evil-define-command +my/ex-diffview-open (&optional rev)
  (interactive "<a>")
  (if rev
      (magit-diff-range rev)
    (magit-diff-working-tree)))
(evil-ex-define-cmd "DiffviewOpen" #'+my/ex-diffview-open)
(evil-ex-define-cmd "DiffviewFileHistory" #'magit-log-buffer-file)
(evil-ex-define-cmd "DiffviewClose" #'magit-mode-bury-buffer)

;; easy-dotnet.nvim: `:Dotnet [build|run|test|restore|clean|watch]'.
(defun +my/dotnet (&optional cmd)
  "Run a dotnet command from the solution root, in a compilation buffer."
  (interactive)
  (let* ((default-directory
          (or (locate-dominating-file
               default-directory
               (lambda (dir) (directory-files dir nil "\\.slnx?\\'" t)))
              (doom-project-root)
              default-directory))
         (cmd (or cmd (completing-read "Dotnet: " '("build" "run" "test" "restore"
                                                     "clean" "watch")))))
    (if (member cmd '("run" "watch"))
        (let* ((projects (if (executable-find "fd")
                             (process-lines "fd" "-e" "csproj")
                           (directory-files-recursively default-directory "\\.csproj\\'")))
               (proj (completing-read "Project: " projects nil t)))
          ;; comint, so the program can read stdin
          (compile (format "dotnet %s --project %s" cmd (shell-quote-argument proj)) t))
      (compile (concat "dotnet " cmd)))))
(evil-define-command +my/ex-dotnet (&optional cmd)
  (interactive "<a>")
  (+my/dotnet cmd))
(evil-ex-define-cmd "Dotnet" #'+my/ex-dotnet)

;; brygga.nvim: `:Brygga [status|start|stop|send]', now on claude-code-ide.
(evil-define-command +my/ex-brygga (beg end &optional sub)
  (interactive "<r><a>")
  (pcase (or sub "status")
    ("start" (claude-code-ide))
    ("stop" (claude-code-ide-stop))
    ("send" (goto-char beg) (set-mark (save-excursion (goto-char end) (point)))
            (activate-mark) (claude-code-ide-insert-at-mentioned))
    (_ (claude-code-ide-list-sessions))))
(evil-ex-define-cmd "Brygga" #'+my/ex-brygga)
