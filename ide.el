;;; $DOOMDIR/ide.el -*- lexical-binding: t; -*-
;;; C# debugging (dape + netcoredbg) and Claude Code (claude-code-ide.el).
;;; Loaded from config.el; keys are in keys.el.

;;; ── C# debugging ────────────────────────────────────────────────────────
;; dape (Doom's :tools debugger) talks to Samsung's netcoredbg. It is looked
;; up in ~/.config/doom/debug-adapters/netcoredbg/ first, then on PATH.
;;
;;   F5 / SPC d c   start (pick a config) / continue    SPC d b  breakpoint
;;   F10 / F11      step over / into   S-F11 step out   SPC d t  stop
;;   SPC d u        the debugger panes (locals, stack, watch, breakpoints)
;;
;; Two configs, picked after F5 in a .cs buffer:
;;   netcoredbg         pick a .csproj → dotnet build → launch its dll, with the
;;                      project folder as cwd (so appsettings*.json are found)
;;   netcoredbg-attach  attach to a running dotnet process (e.g. a service
;;                      started with `pm run' / `dotnet run')

(defun +my/netcoredbg-command ()
  (let ((local (expand-file-name "netcoredbg/netcoredbg"
                                 (doom-user-dir "debug-adapters/"))))
    (if (file-executable-p local) local "netcoredbg")))

(defun +my/dotnet-pick-csproj ()
  "Pick a .csproj under the project (the current buffer's own first)."
  (let* ((root (or (projectile-project-root) default-directory))
         (own (and buffer-file-name
                   (locate-dominating-file buffer-file-name
                                           (lambda (d) (directory-files d nil "\\.csproj\\'")))))
         (all (seq-remove (lambda (f) (string-match-p "/\\(bin\\|obj\\|node_modules\\)/" f))
                          (directory-files-recursively root "\\.csproj\\'")))
         (own-file (and own (car (directory-files own t "\\.csproj\\'")))))
    (completing-read "Project to debug: "
                     (mapcar (lambda (f) (file-relative-name f root))
                             (if own-file (cons own-file (delete own-file all)) all))
                     nil t nil nil (and own-file (file-relative-name own-file root)))))

(defun +my/dotnet-csproj-dll (csproj)
  "The newest Debug dll built from CSPROJ, or nil."
  (let* ((dir (file-name-directory csproj))
         (name (file-name-base csproj))
         (dlls (file-expand-wildcards
                (expand-file-name (format "bin/Debug/*/%s.dll" name) dir))))
    (car (sort dlls #'file-newer-than-file-p))))

(defun +my/netcoredbg-launch-fn (config)
  "Turn the picked .csproj in CONFIG into: build it, run its dll from its folder."
  (let ((prog (plist-get config :program)))
    (if (not (and (stringp prog) (string-suffix-p ".csproj" prog)))
        config
      (let* ((csproj (expand-file-name prog (or (projectile-project-root) default-directory)))
             (dll (+my/dotnet-csproj-dll csproj)))
        (setq config (plist-put config 'compile
                                (format "dotnet build %s -c Debug"
                                        (shell-quote-argument csproj))))
        (setq config (plist-put config :cwd (file-name-directory csproj)))
        ;; Before the first build there is no dll yet; dape re-runs this
        ;; function after compiling, and it is found then.
        (if dll (plist-put config :program dll) config)))))

(defun +my/dotnet-pick-pid ()
  "Pick a running dotnet process."
  (let (cands)
    (dolist (pid (list-system-processes))
      (let* ((attrs (process-attributes pid))
             (args (alist-get 'args attrs)))
        (when (and args (string-match-p "dotnet\\|\\.dll\\b" args)
                   (not (string-match-p "roslyn\\|netcoredbg\\|MSBuild\\|VBCSCompiler\\|language-server" args)))
          (push (cons (format "%-7d %s" pid (truncate-string-to-width args 140)) pid) cands))))
    (unless cands (user-error "No dotnet process running"))
    (cdr (assoc (completing-read "Attach to: " cands nil t) cands))))

(after! dape
  (setf (alist-get 'netcoredbg dape-configs)
        `(modes (csharp-mode csharp-ts-mode)
          ensure dape-ensure-command
          command +my/netcoredbg-command
          command-args ["--interpreter=vscode"]
          fn +my/netcoredbg-launch-fn
          :request "launch"
          :program +my/dotnet-pick-csproj
          :env (:ASPNETCORE_ENVIRONMENT "Development" :DOTNET_ENVIRONMENT "Development")
          :stopAtEntry nil))
  (setf (alist-get 'netcoredbg-attach dape-configs)
        `(modes (csharp-mode csharp-ts-mode)
          ensure dape-ensure-command
          command +my/netcoredbg-command
          command-args ["--interpreter=vscode"]
          :request "attach"
          :processId +my/dotnet-pick-pid)))


;;; ── C# editing ──────────────────────────────────────────────────────────

;; Richer colours from Roslyn (fields, parameters, statics, …) on top of
;; tree-sitter, like Neovim does.
(add-hook! '(csharp-mode-hook csharp-ts-mode-hook)
  (defun +my/csharp-lsp-features-h ()
    (setq-local lsp-semantic-tokens-enable t
                ;; Roslyn re-indents the line as you type `}' `;' or RET,
                ;; following the repo's .editorconfig.
                lsp-enable-on-type-formatting t)
    ;; `=' (and anything using indent-region) goes through Roslyn's formatter
    ;; once it's up: csharp-ts-mode's own rules misplace continuation lines
    ;; (`&& …'). Before Roslyn is ready, the tree-sitter rules are used.
    (setq-local indent-region-function #'+my/csharp-indent-region)))

(defun +my/csharp-indent-region (beg end)
  (if (and (bound-and-true-p lsp-mode)
           (lsp-feature? "textDocument/rangeFormatting"))
      (lsp-format-region beg end)
    (treesit-indent-region beg end)))

;; Text objects and motions from tree-sitter (evil-textobj-tree-sitter), in
;; every buffer that has a tree-sitter parser (elsewhere Doom's stay):
;;   af/if function   aC/iC class   al/il loop   av/iv conditional   ac comment
;;   ]f [f next/previous function    ]C [C next/previous class
(defun +my/ts-textobj-p ()
  (and (fboundp 'treesit-parser-list) (treesit-parser-list)))

(use-package! evil-textobj-tree-sitter
  :if (locate-library "evil-textobj-tree-sitter")   ; until `doom sync'
  :after evil
  :config
  (dolist (spec '(("f" "function.outer" "function.inner")
                  ("C" "class.outer" "class.inner")
                  ("l" "loop.outer" "loop.inner")
                  ("v" "conditional.outer" "conditional.inner")
                  ("c" "comment.outer" "comment.outer")))
    (pcase-let ((`(,key ,outer ,inner) spec))
      (dolist (map-spec `((,evil-outer-text-objects-map ,outer)
                          (,evil-inner-text-objects-map ,inner)))
        (pcase-let* ((`(,map ,query) map-spec)
                     (ts-cmd (eval `(evil-textobj-tree-sitter-get-textobj ,query) t))
                     (old (lookup-key map key)))
          ;; A filtered binding: the tree-sitter object when the buffer has a
          ;; parser, the previous binding otherwise.
          (define-key map key
                      `(menu-item "" ,ts-cmd
                        :filter ,(lambda (cmd) (if (+my/ts-textobj-p) cmd old))))))))
  (map! :n "]f" (cmd! (evil-textobj-tree-sitter-goto-textobj "function.outer"))
        :n "[f" (cmd! (evil-textobj-tree-sitter-goto-textobj "function.outer" t))
        :n "]C" (cmd! (evil-textobj-tree-sitter-goto-textobj "class.outer"))
        :n "[C" (cmd! (evil-textobj-tree-sitter-goto-textobj "class.outer" t))))


;;; ── Roslyn: loading progress in the mode line ───────────────────────────
;; Roslyn only reports project loading to VS Code; to everyone else it just
;; logs "Successfully completed load of X.csproj" per project and
;; "Completed (re)load of all projects" at the end. Those log lines feed
;; lsp-mode's own progress indicator: "Roslyn loading 57/120 projects".
;; (The background compile that follows isn't logged, so it can't be shown.)

(defvar +my/roslyn-load-state (make-hash-table :test #'eq)
  "Workspace -> (LOADED . TOTAL) while Roslyn loads a solution.")

(defun +my/roslyn-count-projects (sln)
  "Number of projects SLN (.sln, .slnx or .slnf) loads."
  (with-temp-buffer
    (insert-file-contents sln)
    (pcase (file-name-extension sln)
      ("slnx" (how-many "<Project[ \t\n]+Path=" (point-min) (point-max)))
      ("slnf" (how-many "\\.csproj\"" (point-min) (point-max)))
      (_ (how-many "^Project(.*\\.csproj\"" (point-min) (point-max))))))

(defun +my/roslyn-progress (workspace kind &optional message pct)
  (funcall lsp-progress-function workspace
           (lsp-make-progress-params
            :token "+my/roslyn-load"
            :value (pcase kind
                     ("begin" (lsp-make-work-done-progress-begin
                               :kind "begin" :title "Roslyn" :message message :percentage pct))
                     ("report" (lsp-make-work-done-progress-report
                                :kind "report" :message message :percentage pct))
                     (_ (lsp-make-work-done-progress-end :kind "end"))))))

(defun +my/roslyn-load-started (workspace sln)
  "Called by config.el right before asking Roslyn to open SLN."
  (puthash workspace (cons 0 (or (ignore-errors (+my/roslyn-count-projects sln)) 0))
           +my/roslyn-load-state)
  (+my/roslyn-progress workspace "begin"
                       (format "opening %s" (file-name-nondirectory sln)) 0))

(defun +my/roslyn-log-progress-a (workspace params)
  (when-let* ((state (gethash workspace +my/roslyn-load-state))
              (msg (lsp-get params :message)))
    (cond
     ((string-match-p "\\[LanguageServerProjectLoader\\] Successfully completed load of" msg)
      (cl-incf (car state))
      (let ((done (car state)) (total (cdr state)))
        (+my/roslyn-progress workspace "report"
                             (if (> total 0)
                                 (format "loading %d/%d projects" (min done total) total)
                               (format "loading %d projects" done))
                             (and (> total 0) (min 99 (/ (* 100 done) total))))))
     ((string-match "\\[solution/open\\].*Completed (re)load of all projects in \\([0-9:]+\\)" msg)
      (remhash workspace +my/roslyn-load-state)
      (+my/roslyn-progress workspace "end")
      (lsp--info "Roslyn: %d projects loaded in %s (the first lookups can be slow while it compiles)"
                 (car state) (match-string 1 msg))))))

(advice-add 'lsp--window-log-message :after #'+my/roslyn-log-progress-a)


;;; ── Claude Code (claude-code-ide.el) ───────────────────────────────────
;; https://github.com/manzaltu/claude-code-ide.el
;; One Claude per project, in a window on the right, each with its own MCP
;; link to Emacs: it sees the file and selection you're on, shows its edits in
;; ediff (edit them, then y/n), and reads flycheck diagnostics. Doom opens each
;; project in its own workspace (SPC p p), so switching workspace and pressing
;; the key again gives you that project's Claude.
;;
;;   SPC a c / C-'  show/hide this project's Claude (starts one if none)
;;   SPC a C        another instance for this project (asks for a name)
;;   Starting a Claude asks which account (claude-work / claude-personal),
;;   with the folder's usual one (`+my/claude-account-rules') pre-selected:
;;   RET accepts it. Set `+my/claude-ask-account' to nil to stop asking.
;;   C-u SPC a c starts another one even when one is running.
;;   SPC a i        send the selection          SPC a l  all sessions
;;   SPC a r / R    continue last / resume a conversation
;;   SPC a q        stop                        SPC a m  menu (everything)
;;   in Claude:  Esc goes to Claude, C-<escape> leaves insert mode,
;;               M-RET newline, C-c C-x drop selection

(use-package! claude-code-ide
  :commands (claude-code-ide claude-code-ide-toggle claude-code-ide-menu
             claude-code-ide-insert-at-mentioned claude-code-ide-list-sessions
             claude-code-ide-continue claude-code-ide-resume claude-code-ide-stop)
  :init
  (setq claude-code-ide-terminal-backend 'vterm
        claude-code-ide-show-backend-recommendation nil
        claude-code-ide-window-side 'right
        claude-code-ide-window-width 100)
  :config
  ;; Let Claude use xref (LSP), imenu, tree-sitter and project info.
  (claude-code-ide-emacs-tools-setup))

;; Esc in a Claude terminal goes to Claude (cancel, Esc Esc to rewind), like
;; in a real terminal; C-<escape> leaves insert mode instead (to scroll, copy,
;; switch window). claude-code-ide's own C-<escape> (send Esc) is swapped.
(define-minor-mode +my/claude-term-mode
  "Keys for Claude Code terminal buffers."
  :keymap (make-sparse-keymap))
(after! evil
  (evil-define-minor-mode-key 'insert '+my/claude-term-mode
    (kbd "<escape>")   #'claude-code-ide-send-escape
    (kbd "C-<escape>") #'evil-normal-state))
(add-hook! 'vterm-mode-hook
  (defun +my/claude-term-h ()
    (when (string-prefix-p "*claude-code[" (buffer-name))
      (+my/claude-term-mode +1)
      (evil-normalize-keymaps))))

;; Which account (your claude-work / claude-personal wrappers) a new Claude
;; uses: the first rule whose folder holds the project wins, else the default.
;; With `+my/claude-ask-account' (the default) it asks, offering that one first.
(defvar +my/claude-ask-account t
  "Non-nil: ask which account each new Claude uses.")
(defvar +my/claude-accounts '("claude-work" "claude-personal"))
(defvar +my/claude-account-rules
  '(("~/projects/" . "claude-personal")
    ("~/.config/"  . "claude-personal"))
  "(FOLDER . COMMAND) pairs; projects under FOLDER use COMMAND.")
(defvar +my/claude-default-account "claude-work")

(defun +my/claude-account ()
  "The account for a new Claude: asked, or picked from the folder rules."
  (let* ((dir (claude-code-ide--get-working-directory))
         (usual (or (cdr (seq-find (lambda (rule) (file-in-directory-p dir (car rule)))
                                   +my/claude-account-rules))
                    +my/claude-default-account)))
    (if +my/claude-ask-account
        (completing-read (format "Claude account (default %s): " usual)
                         (cons usual (remove usual +my/claude-accounts))
                         nil t nil nil usual)
      usual)))

(defun +my/claude-new ()
  "Start another Claude for this project, asking for the account."
  (interactive)
  (require 'claude-code-ide)
  (let ((claude-code-ide-cli-path (+my/claude-account)))
    (message "Claude: starting with %s" claude-code-ide-cli-path)
    (claude-code-ide)))

(defun +my/claude-toggle (&optional new)
  "Show/hide this project's Claude, starting one if it has none.
With C-u, start another one even if one is running."
  (interactive "P")
  (require 'claude-code-ide)
  (if (and (not new)
           (claude-code-ide-mcp--sessions-for-project
            (claude-code-ide--get-working-directory)))
      (claude-code-ide-toggle)
    (+my/claude-new)))
