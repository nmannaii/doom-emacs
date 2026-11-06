;;; $DOOMDIR/docs.el -*- lexical-binding: t; -*-
;;; Org, markdown and vimwiki, ported from ~/.config/nvim (plugins/orgmode.lua,
;;; org-bullets, snacks.image, render-markdown, plugins/vimwiki.lua).
;;; This file is about behaviour (agenda, capture, keys, mermaid, export,
;;; markdown, vimwiki). How org buffers *look* (heading sizes, stars, bullets,
;;; checkboxes, fonts, page column, entities, images, LaTeX) belongs to
;;; org-pretty.el, loaded right after this one from config.el.

;;; ── Markdown headings: bigger font + full-width bar in the level's colour ─
;; Org headings are sized in org-pretty.el.

(defun +my/blend (fg bg alpha)
  "Mix colour FG into BG with weight ALPHA (orgmode.lua's blend())."
  (when-let* ((a (color-name-to-rgb fg))
              (b (color-name-to-rgb bg)))
    (apply #'color-rgb-to-hex
           (append (cl-mapcar (lambda (x y) (+ (* x alpha) (* y (- 1 alpha)))) a b)
                   '(2)))))

(defvar +my/heading-heights '(1.4 1.25 1.15 1.1 1.05 1.0 1.0 1.0)
  "Font scale per heading level.")

(defun +my/heading-faces-h ()
  "Bold, scaled markdown headings, each over a bar tinted with its colour."
  (let ((bg (face-attribute 'default :background nil t)))
    (dotimes (i 8)
      (let ((face (intern (format "markdown-header-face-%d" (1+ i)))))
        (when (facep face)
          (let ((fg (face-attribute face :foreground nil t)))
            (set-face-attribute face nil
                                :weight 'bold
                                :height (nth i +my/heading-heights)
                                :background (and (stringp fg) (stringp bg)
                                                 (+my/blend fg bg 0.15))
                                :extend t)))))))

(add-hook 'doom-load-theme-hook #'+my/heading-faces-h)
(after! markdown-mode (+my/heading-faces-h))


;;; ── Org (orgmode.lua) ────────────────────────────────────────────────────

(setq org-default-notes-file (expand-file-name "refile.org" org-directory))

;; orgmode.lua globs `~/org/**/*'; recompute before each agenda view so new
;; files show up, as they do in nvim.
(defun +my/org-agenda-files-refresh-a (&rest _)
  (setq org-agenda-files (directory-files-recursively org-directory "\\.org\\'")))
(dolist (fn '(org-agenda org-todo-list org-tags-view org-search-view
              org-agenda-redo-all consult-org-agenda))
  (advice-add fn :before #'+my/org-agenda-files-refresh-a))

(after! org
  (setq org-startup-folded 'showeverything  ; a file's #+STARTUP still wins
        org-startup-indented t
        ;; nvim-orgmode defaults (Doom ships many more keywords/templates)
        org-todo-keywords '((sequence "TODO" "|" "DONE"))
        org-capture-templates
        '(("t" "Task" entry (file org-default-notes-file) "* TODO %?\n  %u"))))

;; conceallevel=2 + concealcursor=nc: markup stays hidden in normal state and
;; is revealed under the cursor while in insert state.
(after! org-appear
  (setq org-appear-trigger 'manual
        org-appear-autoemphasis t
        org-appear-autolinks t
        org-appear-autosubmarkers t))
(add-hook! 'org-mode-hook
  (defun +my/org-appear-on-insert-h ()
    (add-hook 'evil-insert-state-entry-hook #'org-appear-manual-start nil t)
    (add-hook 'evil-insert-state-exit-hook #'org-appear-manual-stop nil t)))

(defun +my/org-format-tables ()
  "Realign every table in the buffer, without reflowing paragraphs.
Takes over <leader>cf in org buffers, like orgmode.lua."
  (interactive)
  (let ((n 0))
    (org-table-map-tables (lambda () (org-table-align) (cl-incf n)) t)
    (message "Formatted %d table(s)" n)))


;;; ── Mermaid: inline previews (snacks.image) ──────────────────────────────
;; Each `#+begin_src mermaid' block gets its rendered diagram shown below it,
;; refreshed on save. Renders are cached by content hash. Needs `mmdc'.
;; Blocks with a `:file' header are left alone: those are run with C-c C-c
;; (ob-mermaid, org-pretty.el) and their result image is already inline.

(defvar +my/mermaid-cache-dir
  (expand-file-name "org-mermaid-preview/"
                    (or (getenv "XDG_CACHE_HOME") "~/.cache")))
(defvar +my/mermaid--pending (make-hash-table :test #'equal)
  "Files currently being rendered, so refreshes don't start duplicate mmdc runs.")
(defvar-local +my/org-mermaid--overlays nil)

(defun +my/mermaid--theme ()
  (if (eq (frame-parameter nil 'background-mode) 'light) "neutral" "dark"))

(defun +my/org-mermaid--blocks ()
  "Return (EOL-OF-END-LINE . CODE) for each mermaid src block."
  (let ((case-fold-search t) blocks)
    (org-with-wide-buffer
     (goto-char (point-min))
     (while (re-search-forward "^[ \t]*#\\+begin_src[ \t]+mermaid\\_>" nil t)
       (let ((el (org-element-at-point)))
         (when (and (eq (org-element-type el) 'src-block)
                    (not (string-match-p ":file\\_>"
                                         (or (org-element-property :parameters el) ""))))
           (save-excursion
             (goto-char (org-element-property :end el))
             (skip-chars-backward " \t\n")
             (push (cons (line-end-position) (org-element-property :value el))
                   blocks))))))
    (nreverse blocks)))

(defun +my/mermaid--render (code file theme callback)
  "Render CODE to FILE with mmdc (3x, so the GUI only ever downsamples)."
  (unless (gethash file +my/mermaid--pending)
    (make-directory +my/mermaid-cache-dir t)
    (puthash file t +my/mermaid--pending)
    (let ((src (make-temp-file "mermaid" nil ".mmd" code)))
      (make-process
       :name "mmdc" :buffer " *mmdc*" :noquery t
       :command (list "mmdc" "-i" src "-o" file "-b" "transparent"
                      "-t" theme "-s" "3" "--quiet")
       :sentinel (lambda (proc _event)
                   (unless (process-live-p proc)
                     (remhash file +my/mermaid--pending)
                     (delete-file src)
                     (if (and (zerop (process-exit-status proc)) (file-exists-p file))
                         (funcall callback)
                       (message "mermaid: render failed, see buffer \" *mmdc*\""))))))))

(defun +my/org-mermaid--show (pos file)
  (let* ((win (or (get-buffer-window) (selected-window)))
         (img (create-image file 'png nil
                            :scale (/ (image-compute-scaling-factor image-scaling-factor) 3.0)
                            :max-width (truncate (* 0.95 (window-body-width win t)))))
         (ov (make-overlay pos pos nil t nil)))
    (overlay-put ov 'after-string (concat "\n" (propertize " " 'display img)))
    (push ov +my/org-mermaid--overlays)))

(defun +my/org-mermaid-refresh ()
  "Re-render and redisplay every mermaid block preview in this buffer."
  (interactive)
  (mapc #'delete-overlay +my/org-mermaid--overlays)
  (setq +my/org-mermaid--overlays nil)
  (when (and (display-images-p) (executable-find "mmdc"))
    (let ((buf (current-buffer))
          (theme (+my/mermaid--theme)))
      (pcase-dolist (`(,pos . ,code) (+my/org-mermaid--blocks))
        (let ((file (expand-file-name (concat (sha1 (concat theme code)) ".png")
                                      +my/mermaid-cache-dir)))
          (if (file-exists-p file)
              (+my/org-mermaid--show pos file)
            (+my/mermaid--render
             code file theme
             (lambda ()
               (when (buffer-live-p buf)
                 (with-current-buffer buf (+my/org-mermaid-refresh)))))))))))

(define-minor-mode +my/org-mermaid-preview-mode
  "Show mermaid src blocks rendered below themselves."
  :lighter nil
  (if +my/org-mermaid-preview-mode
      (progn (add-hook 'after-save-hook #'+my/org-mermaid-refresh nil t)
             (+my/org-mermaid-refresh))
    (remove-hook 'after-save-hook #'+my/org-mermaid-refresh t)
    (mapc #'delete-overlay +my/org-mermaid--overlays)
    (setq +my/org-mermaid--overlays nil)))

(add-hook 'org-mode-hook #'+my/org-mermaid-preview-mode)
(add-hook! 'doom-load-theme-hook
  (defun +my/org-mermaid-retheme-h ()
    (dolist (buf (buffer-list))
      (with-current-buffer buf
        (when +my/org-mermaid-preview-mode (+my/org-mermaid-refresh))))))


;;; ── Mermaid: export through pandoc (orgmode.lua's custom `M' export) ─────

(defvar +my/pandoc-mermaid-filter
  (expand-file-name "pandoc/mermaid.lua" doom-user-dir))

(defun +my/org-export-pandoc-mermaid (ext args)
  "Export this file to EXT with pandoc, embedding mermaid blocks as images."
  (save-buffer)                         ; pandoc reads the file from disk
  (let* ((file (buffer-file-name))
         (target (concat (file-name-sans-extension file) "." ext))
         (log (get-buffer-create "*pandoc export*")))
    (with-current-buffer log (erase-buffer))
    (message "pandoc: exporting %s..." (file-name-nondirectory target))
    (make-process
     :name "pandoc" :buffer log :noquery t
     :command `("pandoc" ,file "-o" ,target
                ,(concat "--lua-filter=" +my/pandoc-mermaid-filter)
                ,(concat "--resource-path=" (file-name-directory file))
                ,@args)
     :sentinel (lambda (proc _event)
                 (unless (process-live-p proc)
                   (if (zerop (process-exit-status proc))
                       (message "Exported %s" target)
                     (message "pandoc failed, see *pandoc export*")))))))

(after! ox
  ;; The parent `org' backend lives in ox-org, which isn't in
  ;; `org-export-backends' by default: without this, loading ox errors out
  ;; ("Cannot use unknown \"org\" backend as a parent"), which breaks export
  ;; and anything that pulls ox in (inline images, links...).
  (require 'ox-org)
  (org-export-define-derived-backend 'pandoc-mermaid 'org
    :menu-entry
    `(?M "Export with Mermaid diagrams (pandoc)"
      ((?h "HTML (self-contained)"
           ,(lambda (&rest _) (+my/org-export-pandoc-mermaid
                               "html" '("--standalone" "--embed-resources"))))
       (?p "PDF" ,(lambda (&rest _) (+my/org-export-pandoc-mermaid
                                     "pdf" '("--pdf-engine=xelatex"))))
       (?w "Word" ,(lambda (&rest _) (+my/org-export-pandoc-mermaid "docx" nil)))
       (?m "Markdown (GFM, keeps ```mermaid)"
           ,(lambda (&rest _) (+my/org-export-pandoc-mermaid "md" '("-t" "gfm"))))))))


;;; ── nvim-orgmode keys (non-leader; leader ones are in keys.el) ───────────

;; cit / ciT / cid / ciR / cir are operator+motion combos in evil.
;; (<s / >s would shadow evil-surround's `s'; use evil-org's <aR / >aR.)
;; These text objects run the org action and cancel the operator when it is the
;; one nvim-orgmode maps; any other operator (dir, yiR...) gets FALLBACK.
(defmacro +my/org-operator-key! (name operator action &optional fallback)
  `(evil-define-text-object ,name (count &optional beg end type)
     (if (and (eq evil-this-operator ,operator) (derived-mode-p 'org-mode))
         (progn (setq evil-inhibit-operator t)
                ,action
                (list (point) (point)))
       ,(if fallback
            `(funcall #',fallback count beg end type)
          '(list (point) (point))))))

(+my/org-operator-key! +my/org-cit #'evil-change (org-todo 'right) evil-inner-tag)
(+my/org-operator-key! +my/org-ciT #'evil-change (org-todo 'left))
(+my/org-operator-key! +my/org-cid #'evil-change (org-time-stamp nil))
(+my/org-operator-key! +my/org-ciR #'evil-change (org-priority-up) evil-org-inner-subtree)
(+my/org-operator-key! +my/org-cir #'evil-change (org-priority-down) evil-org-inner-subtree)

(defun +my/org-timestamp-or-number (n)
  "<C-a>/<C-x>: shift the timestamp at point, else the number (vim default)."
  (if (org-at-timestamp-p 'lax)
      (org-timestamp-up n)
    (evil-numbers/inc-at-pt n)))

(map! :after evil-org
      :map evil-org-mode-map
      :o "it" #'+my/org-cit
      :o "iT" #'+my/org-ciT
      :o "id" #'+my/org-cid
      :o "iR" #'+my/org-ciR
      :o "ir" #'+my/org-cir
      :n "}"  #'org-next-visible-heading
      :n "{"  #'org-previous-visible-heading
      :n "]]" #'org-forward-heading-same-level
      :n "[[" #'org-backward-heading-same-level
      :n "g{" #'outline-up-heading
      :n "C-SPC" #'org-toggle-checkbox
      ;; <C-x> (decrement) stays the Emacs C-x prefix; use g- / S-<down>.
      :n "C-a" (cmd! (+my/org-timestamp-or-number 1))
      :n "S-<up>"   #'org-timestamp-up-day
      :n "S-<down>" #'org-timestamp-down-day)

;; Capture / note buffers: <C-c> finalizes (the leader k/r keys are in keys.el).
(map! :after org-capture
      :map org-capture-mode-map
      :n "C-c" #'org-capture-finalize)


;;; ── Markdown (render-markdown + LazyVim's wrap/conceal) ─────────────────

(after! markdown-mode
  (setq markdown-hide-markup t
        markdown-fontify-code-blocks-natively t
        markdown-make-gfm-checkboxes-buttons t
        markdown-list-item-bullets '("•" "◦" "▪" "▫")
        markdown-enable-wiki-links t
        markdown-command "pandoc"))

;; LazyVim's wrap_spell autocmd: soft-wrap prose (spell needs a hunspell
;; dictionary, see the :checkers spell module in init.el).
(add-hook! '(markdown-mode-hook git-commit-mode-hook) #'visual-line-mode)


;;; ── vimwiki (~/vimwiki, markdown syntax) ────────────────────────────────

(defvar +my/vimwiki-dir (expand-file-name "~/vimwiki/"))

(defun +my/vimwiki-index ()
  (interactive)
  (find-file (expand-file-name "index.md" +my/vimwiki-dir)))

(defun +my/vimwiki-index-tab ()
  (interactive)
  (+workspace/new)
  (+my/vimwiki-index))

(defun +my/vimwiki-diary-file (&optional days)
  (expand-file-name (format-time-string "diary/%Y-%m-%d.md"
                                        (time-add nil (* 86400 (or days 0))))
                    +my/vimwiki-dir))

(defun +my/vimwiki-diary-index ()
  (interactive)
  (find-file (expand-file-name "diary/diary.md" +my/vimwiki-dir)))

(defun +my/vimwiki-diary-generate-links ()
  "Rewrite diary/diary.md as a list of every diary page, newest first."
  (interactive)
  (let* ((dir (expand-file-name "diary/" +my/vimwiki-dir))
         (pages (reverse (directory-files dir nil "\\`[0-9-]\\{10\\}\\.md\\'"))))
    (find-file (expand-file-name "diary.md" dir))
    (erase-buffer)
    (insert "# Diary\n\n")
    (dolist (p pages)
      (let ((name (file-name-sans-extension p)))
        (insert (format "- [%s](%s)\n" name name))))
    (save-buffer)))

(defun +my/vimwiki--target (target)
  "vimwiki links omit the extension: [Page](Page) -> Page.md."
  (if (or (string-match-p "://" target) (file-name-extension target))
      target
    (concat target ".md")))

(defun +my/vimwiki-follow-or-create ()
  "<CR>: follow the link at point, or turn the word/selection into a link."
  (interactive)
  (cond
   ((markdown-link-p)
    (let ((url (markdown-link-url)))
      (if (string-match-p "://" url)
          (browse-url url)
        (find-file (expand-file-name (+my/vimwiki--target url)
                                     (file-name-directory buffer-file-name))))))
   ((markdown-wiki-link-p) (markdown-follow-wiki-link-at-point))
   (t
    (let* ((bounds (if (evil-visual-state-p)
                       (cons (region-beginning) (region-end))
                     (bounds-of-thing-at-point 'symbol)))
           (text (and bounds (buffer-substring-no-properties (car bounds) (cdr bounds)))))
      (when text
        (evil-normal-state)
        (delete-region (car bounds) (cdr bounds))
        (goto-char (car bounds))
        (insert (format "[%s](%s)" text text))
        (goto-char (car bounds)))))))

(define-minor-mode +my/vimwiki-mode
  "vimwiki's buffer keys for markdown files under `+my/vimwiki-dir'."
  :keymap (make-sparse-keymap))

(add-hook! 'markdown-mode-hook
  (defun +my/vimwiki-maybe-enable-h ()
    (when (and buffer-file-name
               (file-in-directory-p buffer-file-name +my/vimwiki-dir))
      (+my/vimwiki-mode +1))))
(add-hook '+my/vimwiki-mode-hook #'evil-normalize-keymaps)

(map! :map +my/vimwiki-mode-map
      :nv "RET"       #'+my/vimwiki-follow-or-create
      :n  "DEL"       #'previous-buffer
      :n  "TAB"       #'markdown-next-link
      :n  "<backtab>" #'markdown-previous-link
      :n  "C-SPC"     #'markdown-toggle-gfm-checkbox
      :n  "="         #'markdown-demote    ; vimwiki: add a header level
      :n  "-"         #'markdown-promote)  ; remove one
