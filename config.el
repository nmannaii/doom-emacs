;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
;; tokyonight, like LazyVim; <leader>ub flips to the light theme.
(defvar +my/dark-theme 'doom-tokyo-night)
(defvar +my/light-theme 'doom-one-light)
(setq doom-theme +my/dark-theme)

;; Doom's tokyo-night paints types, properties and names the same near-white
;; as plain text; this is the original theme's mapping (as in Neovim), for
;; tree-sitter and for LSP semantic tokens (C# via Roslyn).
(custom-theme-set-faces! 'doom-tokyo-night
  '(font-lock-type-face              :foreground "#2ac3de")           ; types
  '(font-lock-function-name-face     :foreground "#7aa2f7")           ; methods
  '(font-lock-function-call-face     :foreground "#7aa2f7")
  '(font-lock-property-name-face     :foreground "#73daca")           ; properties
  '(font-lock-property-use-face      :foreground "#73daca")
  '(font-lock-variable-name-face     :foreground "#c0caf5")           ; declared names
  '(font-lock-constant-face          :foreground "#ff9e64")           ; constants
  '(font-lock-number-face            :foreground "#ff9e64")
  '(font-lock-builtin-face           :foreground "#2ac3de")
  '(font-lock-doc-face               :foreground "#565f89" :slant italic)
  '(lsp-face-semhl-namespace         :foreground "#a9b1d6")
  '(lsp-face-semhl-type              :foreground "#2ac3de")
  '(lsp-face-semhl-class             :foreground "#2ac3de")
  '(lsp-face-semhl-interface         :foreground "#2ac3de")
  '(lsp-face-semhl-struct            :foreground "#2ac3de")
  '(lsp-face-semhl-enum              :foreground "#2ac3de")
  '(lsp-face-semhl-type-parameter    :foreground "#2ac3de")
  '(lsp-face-semhl-property          :foreground "#73daca")
  '(lsp-face-semhl-member            :foreground "#73daca")
  '(lsp-face-semhl-enum-member       :foreground "#ff9e64")
  '(lsp-face-semhl-parameter         :foreground "#e0af68")
  '(lsp-face-semhl-variable          :foreground "#c0caf5")
  '(lsp-face-semhl-function          :foreground "#7aa2f7")
  '(lsp-face-semhl-method            :foreground "#7aa2f7")
  '(lsp-face-semhl-keyword           :foreground "#bb9af7")
  '(lsp-face-semhl-string            :foreground "#9ece6a")
  '(lsp-face-semhl-number            :foreground "#ff9e64")
  '(lsp-face-semhl-comment           :foreground "#565f89" :slant italic))

(setq doom-font (font-spec :family "JetBrainsMono Nerd Font Mono" :size 16)
      ;; Proportional font for prose in org (mixed-pitch-mode, see org-pretty.el).
      ;; Noto Sans is the best one installed; for a nicer one:
      ;; `sudo pacman -S inter-font' and use "Inter".
      doom-variable-pitch-font (font-spec :family "Noto Sans" :size 16)
      doom-big-font (font-spec :family "JetBrainsMono Nerd Font Mono" :size 24))


;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type 'relative)

;; LazyVim's editor feel: scrolloff=4, splitbelow/splitright, which-key that
;; pops up right away.
(setq scroll-margin 4
      evil-split-window-below t
      evil-vsplit-window-right t)
(after! which-key
  (setq which-key-idle-delay 0.3
        which-key-idle-secondary-delay 0.05))

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
;; Neovim/LazyVim-style keybindings, then org/markdown/vimwiki.
(load! "keys")
(load! "docs")
(load! "org-pretty")
(load! "ide")

;; A GUI Emacs started from the desktop doesn't get the shell's PATH, so add
;; where the tools live: node (mmdc, ngserver), claude, dotnet tools (Roslyn).
(dolist (dir (append (last (file-expand-wildcards "~/.nvm/versions/node/*/bin"))
                     (list (expand-file-name "~/.local/bin")
                           (expand-file-name "~/.dotnet/tools"))
                     (when (featurep :system 'windows)
                       (delq nil (list (and (getenv "APPDATA")
                                            (expand-file-name "npm" (getenv "APPDATA")))
                                       (and (getenv "ProgramFiles")
                                            (expand-file-name "nodejs" (getenv "ProgramFiles"))))))))
  (when (and (file-directory-p dir) (not (member dir exec-path)))
    (add-to-list 'exec-path dir)
    (setenv "PATH" (concat dir path-separator (getenv "PATH")))))

;; nvim-cmp in LazyVim: <Tab> jumps through snippets, it doesn't cycle items.
(setq +corfu-want-tab-prefer-navigating-snippets t)

;; ── Formatting (conform.lua): format on save, as LazyVim does ───────────
;; html (Angular templates) goes through js-beautify; cs/ts use the LSP
;; formatter (Doom's +lsp flag); lua uses stylua.
(set-formatter! 'html-beautify-angular
  '("js-beautify" "--type" "html" "--templating" "angular"
    "--wrap-attributes" "force-aligned" "--indent-size" "2"))
(add-hook! '(web-mode-hook html-mode-hook mhtml-mode-hook html-ts-mode-hook)
  (defun +my/html-use-js-beautify-h ()
    ;; set before lsp attaches, so Doom doesn't swap in the LSP formatter
    (when (and buffer-file-name (string-match-p "\\.html?\\'" buffer-file-name))
      (setq-local +format-with 'html-beautify-angular))))

;; Fetch/compile missing tree-sitter grammars (c-sharp, typescript, html…)
;; on first use instead of asking every time.
(setq treesit-auto-install-grammar 'always)

;; ── LSP: general ─────────────────────────────────────────────────────────
(after! lsp-mode
  (setq lsp-idle-delay 0.3
        lsp-log-io nil
        ;; PushManager has ~8k dirs even outside node_modules/bin/obj, so
        ;; lsp-mode's watcher would nag/choke. Roslyn watches files itself.
        lsp-enable-file-watchers nil
        ;; Use each project's node_modules/typescript (5.9, matches Angular 20)
        ;; rather than the global one.
        lsp-clients-typescript-prefer-use-project-ts-server t
        ;; Only the servers we actually want (no fallbacks / download prompts).
        lsp-disabled-clients '(omnisharp csharp-ls csharp-roslyn
                               flow-ls deno-ls jsts-ls tsgo))

  ;; Pin the LSP root per language instead of prompting (or reusing the git
  ;; root for everything):
  ;;  - Angular files -> nearest dir with angular.json (the ClientApp)
  ;;  - C# files      -> nearest dir with a .sln/.slnx (repo root)
  (defun +my/lsp-root-a (_session file-name)
    (when-let* ((root
                 (cond
                  ((string-match-p "\\.\\(ts\\|html\\|s?css\\)\\'" file-name)
                   (locate-dominating-file file-name "angular.json"))
                  ((string-match-p "\\.\\(cs\\|razor\\|cshtml\\)\\'" file-name)
                   (locate-dominating-file
                    file-name
                    (lambda (dir) (directory-files dir nil "\\.slnx?\\'" t)))))))
      (lsp-f-canonical root)))
  (advice-add 'lsp--calculate-root :before-until #'+my/lsp-root-a))

;; ── LSP: Angular (ngserver add-on next to ts-ls / html-ls) ──────────────
(defun +my/angular-root (&optional file)
  (when-let* ((file (or file buffer-file-name)))
    (locate-dominating-file file "angular.json")))

(after! lsp-angular
  ;; Stock activation requires angular.json at the *session* root; ours are
  ;; nested ClientApp dirs, so look upward from the file instead.
  ;; (aset, not setf: the struct's gv isn't known when config.el is expanded)
  (aset (gethash 'angular-ls lsp-clients)
        (cl-struct-slot-offset 'lsp--client 'activation-fn)
        (lambda (file-name _mode)
          (and file-name
               (string-match-p "\\.\\(html\\|ts\\)\\'" file-name)
               (+my/angular-root file-name)))))

(defun +my/angular-set-server-command-h ()
  "Point ngserver at the project's own typescript (matches its Angular
version), falling back to the globally installed one. ngserver itself comes
from whatever node nvm currently puts on PATH."
  (when-let* ((root (+my/angular-root))
              (ngserver (executable-find "ngserver")))
    (let ((global (expand-file-name "../lib/node_modules"
                                    (file-name-directory ngserver)))
          (local (expand-file-name "node_modules" root)))
      (setq-local lsp-clients-angular-language-server-command
                  (list ngserver "--stdio"
                        "--tsProbeLocations" (concat local "," global)
                        "--ngProbeLocations"
                        (concat local ","
                                (expand-file-name
                                 "@angular/language-server/node_modules" global)))))))

;; Must run before Doom's lsp! (which is appended to the same hooks).
(add-hook! '(typescript-mode-local-vars-hook typescript-ts-mode-local-vars-hook
             web-mode-local-vars-hook html-mode-local-vars-hook
             html-ts-mode-local-vars-hook)
           #'+my/angular-set-server-command-h)

;; ── LSP: C# via Microsoft's roslyn-language-server (dotnet tool) ────────
;; Right after loading, Roslyn's first references/rename on a big solution can
;; take a minute or two (it compiles every project once); later ones take ~1s.
;; lsp-mode's default 10s would give up on that first one.
(add-hook! '(csharp-mode-hook csharp-ts-mode-hook)
  (defun +my/roslyn-timeout-h () (setq-local lsp-response-timeout 180)))

;; lsp-mode's built-in `csharp-roslyn' client downloads Roslyn 4.13 and talks
;; over a named-pipe handshake that current servers (5.x) no longer do, and
;; its solution search only matches *.sln (not PushManager.slnx). This client
;; runs the `roslyn-language-server' dotnet tool over stdio instead.
(after! lsp-roslyn
  ;; Which solution Roslyn loads: the root .slnx/.sln or one of the .slnf
  ;; filters (e.g. GeneralManagement.slnf, far fewer projects, faster). Asked
  ;; when the server starts and there's more than one; the last pick is the
  ;; default. `SPC c P' asks again and restarts the server.
  (defvar +my/roslyn-solutions (make-hash-table :test #'equal)
    "Solution root -> solution file picked for it.")

  (defun +my/roslyn-root ()
    (when buffer-file-name
      (locate-dominating-file buffer-file-name
                              (lambda (dir) (directory-files dir nil "\\.slnx?\\'" t)))))

  (defun +my/roslyn-candidates (root)
    (append (directory-files root t "\\.slnx?\\'")
            (seq-remove (lambda (f) (string-match-p "/\\(node_modules\\|bin\\|obj\\)/" f))
                        (append (directory-files root t "\\.slnf\\'")
                                (file-expand-wildcards (expand-file-name "*/*.slnf" root))))))

  (defun +my/roslyn-pick (root &optional force no-ask)
    "The solution to load for ROOT, asking when there is a choice.
Never asks when NO-ASK (the server's own callbacks can't prompt): then it
falls back to the root .slnx/.sln."
    (let* ((root (file-name-as-directory (expand-file-name root)))
           (cands (+my/roslyn-candidates root))
           (prev (gethash root +my/roslyn-solutions)))
      (cond
       ((and prev (not force) (file-exists-p prev)) prev)
       ((or no-ask (null (cdr cands))) (car cands))
       (t (let* ((rel (mapcar (lambda (f) (file-relative-name f root)) cands))
                 (def (if prev (file-relative-name prev root) (car rel)))
                 (pick (completing-read (format "Roslyn solution (default %s): " def)
                                        rel nil t nil nil def)))
            (puthash root (expand-file-name pick root) +my/roslyn-solutions))))))

  (defun +my/roslyn-switch-solution ()
    "Pick another solution for this repo and restart Roslyn on it."
    (interactive)
    (let ((root (or (+my/roslyn-root) (user-error "No .sln/.slnx above this file"))))
      (+my/roslyn-pick root t)
      (if-let* ((ws (seq-find (lambda (w) (eq (lsp--client-server-id (lsp--workspace-client w)) 'roslyn-ls))
                              (lsp-workspaces))))
          (lsp-workspace-restart ws)
        (lsp))))

  (defun +my/roslyn-command ()
    ;; Ask now, while the user is the one opening a C# file.
    (when-let* ((root (+my/roslyn-root))) (+my/roslyn-pick root))
    (list (or (executable-find "roslyn-language-server")
              (expand-file-name "~/.dotnet/tools/roslyn-language-server"))
          "--stdio"
          "--logLevel=Information"
          (format "--extensionLogDirectory=%s" lsp-roslyn-server-log-directory)
          (format "--clientProcessId=%d" (emacs-pid))))

  (defun +my/roslyn-open-solution (workspace)
    ;; Roslyn advertises only ranged semantic tokens (what VS Code uses) but
    ;; answers whole-file requests too; lsp-mode only does whole-file ones and
    ;; checks the advertised capability, so mark it as supported.
    (when-let* ((caps (lsp--workspace-server-capabilities workspace))
                (sem (lsp-get caps :semanticTokensProvider)))
      (unless (lsp-get sem :full)
        (lsp-put sem :full t)))
    (with-lsp-workspace workspace
      (if-let* ((root (lsp--workspace-root workspace))
                (sln (+my/roslyn-pick root nil t)))
          (progn (lsp--info "Roslyn: opening %s" (file-name-nondirectory sln))
                 (when (fboundp '+my/roslyn-load-started)   ; ide.el
                   (+my/roslyn-load-started workspace sln))
                 (lsp-notify "solution/open"
                             (list :solution (lsp--path-to-uri sln))))
        (lsp--warn "Roslyn: no .sln/.slnx in %s" root))))

  (lsp-register-client
   (make-lsp-client
    :new-connection (lsp-stdio-connection #'+my/roslyn-command)
    :priority 10
    :server-id 'roslyn-ls
    :activation-fn (lsp-activate-on "csharp")
    :notification-handlers
    (ht ("workspace/projectInitializationComplete"
         #'lsp-roslyn--on-project-initialization-complete)
        ("razor/log" #'ignore)
        ;; VS Code-style popups (e.g. "projects need restore"): show in the
        ;; echo area / *Messages* instead of lsp-mode's "Unknown notification".
        ("window/_roslyn_showToast"
         (lambda (_w params)
           (let ((msg (or (lsp-get params :message) ""))
                 (type (or (lsp-get params :messageType) 3)))
             (if (memql type '(1 2))
                 (lsp--warn "Roslyn: %s" msg)
               (lsp--info "Roslyn: %s" msg))))))
    :request-handlers
    (ht ("workspace/_roslyn_projectNeedsRestore"
         (lambda (_w _params)
           (lsp--warn "Roslyn: some projects need `dotnet restore`")
           nil)))
    :path->uri-fn #'lsp-roslyn--path-to-uri
    :uri->path-fn #'lsp-roslyn--uri-to-path
    :initialized-fn #'+my/roslyn-open-solution)))

;;; ── END CONFIG ────────────────────────────────────────────────────────────
