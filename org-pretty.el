;;; $DOOMDIR/org-pretty.el -*- lexical-binding: t; -*-
;;; Org buffers that read like documents. Builds on (org +pretty), which already
;;; turns on org-modern (styled stars, tags, todo labels, blocks, tables) and
;;; org-appear (emphasis markers only show under the cursor). Loaded from
;;; config.el; packages in packages.el (olivetti, org-fragtog, ob-mermaid).

;;; Prose font: mixed-pitch-mode (from :ui zen) sets prose in
;;; `doom-variable-pitch-font' (config.el) while code, tables, timestamps and
;;; drawers stay monospaced.

;;; ── Org display ─────────────────────────────────────────────────────────
(after! org
  (setq org-ellipsis " ▾"
        org-hide-emphasis-markers t        ; org-appear shows them while editing
        org-pretty-entities t              ; \alpha → α, x^2 → x²
        org-startup-with-inline-images t
        org-image-actual-width '(640)      ; unless #+ATTR_ORG: :width says otherwise
        org-fontify-quote-and-verse-blocks t
        org-fontify-whole-heading-line t
        org-fontify-done-headline t
        org-tags-column 0                  ; tags right after the title (org-modern styles them)
        org-agenda-tags-column 0
        org-auto-align-tags nil
        org-catch-invisible-edits 'show-and-error
        org-highlight-latex-and-related '(native script entities)
        ;; LaTeX fragments as images (rendered on open by `+my/org-page-h',
        ;; which unlike `org-startup-with-latex-preview' can't break opening
        ;; the file when LaTeX fails).
        org-preview-latex-default-process 'dvipng)
  (plist-put org-format-latex-options :scale 1.5)  ; sized for the 16px prose font
  ;; Images made by babel (mermaid, plots) show up right after C-c C-c.
  (add-hook 'org-babel-after-execute-hook #'org-redisplay-inline-images))

;; Heading sizes: a clear hierarchy, like a rendered page.
(custom-set-faces!
  '(org-document-title :height 1.9 :weight bold)
  '(org-document-info :height 1.15)
  '(org-level-1 :height 1.45 :weight bold)
  '(org-level-2 :height 1.3 :weight bold)
  '(org-level-3 :height 1.18 :weight semi-bold)
  '(org-level-4 :height 1.1 :weight semi-bold)
  '(org-level-5 :height 1.05 :weight semi-bold)
  '(org-level-6 :weight semi-bold)
  '(org-ellipsis :underline nil :box nil :height 0.8)
  '(org-block-begin-line :height 0.85 :slant italic :extend t)
  '(org-block-end-line :height 0.85 :slant italic :extend t)
  '(org-quote :slant italic :extend t)
  ;; org-modern's labels (dates, tags, TODO keywords) default to 80%, condensed:
  ;; too small next to the prose font.
  '(org-modern-label :height 0.95 :width normal)
  '(org-done :strike-through nil)
  '(org-headline-done :strike-through t))

;;; ── org-modern ──────────────────────────────────────────────────────────
(after! org-modern
  (setq org-modern-star 'replace
        org-modern-replace-stars "◉○◈◇◆▸"
        org-modern-list '((?- . "•") (?+ . "◦") (?* . "▹"))
        org-modern-checkbox '((?X . "✓") (?- . "◐") (?\s . "˟"))
        org-modern-table-vertical 1
        org-modern-table-horizontal 0.2
        org-modern-block-name '("‣ " . "")
        org-modern-keyword "‣ "
        org-modern-horizontal-rule t
        org-modern-progress '("○" "◔" "◑" "◕" "●")))

;; TODO labels in the theme's colours; rebuilt when the theme changes
;; (<leader>ub flips dark/light), since org-modern bakes them into its keywords.
(defun +my/org-modern-faces-h ()
  (when (fboundp 'doom-color)
    (let ((fg (doom-color 'bg)))
      (setq org-modern-todo-faces
            `(("TODO" :background ,(doom-color 'red) :foreground ,fg :weight bold)
              ("NEXT" :background ,(doom-color 'blue) :foreground ,fg :weight bold)
              ("STRT" :background ,(doom-color 'blue) :foreground ,fg :weight bold)
              ("WAIT" :background ,(doom-color 'yellow) :foreground ,fg :weight bold)
              ("HOLD" :background ,(doom-color 'yellow) :foreground ,fg :weight bold)
              ("PROJ" :background ,(doom-color 'magenta) :foreground ,fg :weight bold)
              ("DONE" :background ,(doom-color 'base5) :foreground ,fg)
              ("CANCELLED" :background ,(doom-color 'base4) :foreground ,fg)
              ("KILL" :background ,(doom-color 'base4) :foreground ,fg))
            org-modern-priority-faces
            `((?A :background ,(doom-color 'red) :foreground ,fg)
              (?B :background ,(doom-color 'orange) :foreground ,fg)
              (?C :background ,(doom-color 'base5) :foreground ,fg)))))
  (dolist (buf (buffer-list))
    (with-current-buffer buf
      (when (bound-and-true-p org-modern-mode)
        (org-modern-mode -1)
        (org-modern-mode 1)))))
(after! org-modern (+my/org-modern-faces-h))
(add-hook 'doom-load-theme-hook #'+my/org-modern-faces-h)

;;; ── Page layout and text size ───────────────────────────────────────────
;; Text in a centred column with some air between lines, no line numbers:
;; a page rather than a code buffer. `SPC t o' toggles the column.
;;
;; Resizing: C-= / C-- zoom the current buffer, C-+ goes back to 100%;
;; M-C-= / M-C-- resize every buffer (the fonts themselves are in config.el).
;; The page is measured in characters, so it widens as the text grows and
;; lines keep a readable length; it never gets wider than the window.

(defvar +my/org-text-scale 1
  "Zoom steps for org buffers (each step is x1.2; 0 = normal, 1 = x1.2).")

(use-package! olivetti
  :if (locate-library "olivetti")
  :commands olivetti-mode
  :init
  (setq olivetti-body-width 110            ; characters, scaled with C-= / C--
        olivetti-style 'fancy               ; margins tinted like the fringe
        olivetti-minimum-body-width 60))

(add-hook! 'org-mode-hook
  (defun +my/org-page-h ()
    (setq-local line-spacing 0.2
                display-line-numbers nil)
    (text-scale-set +my/org-text-scale)
    (when (fboundp 'mixed-pitch-mode)
      (mixed-pitch-mode 1))
    ;; Guarded so org still opens before `doom sync' has installed olivetti.
    (when (fboundp 'olivetti-mode)
      (olivetti-mode 1))
    ;; Render the math; a LaTeX problem is reported, never fatal.
    (when (and buffer-file-name
               (save-excursion (goto-char (point-min))
                               (re-search-forward "\\\\[[(]\\|\\\\begin{\\|\\$[^$\n]+\\$" nil t)))
      (with-demoted-errors "LaTeX preview failed: %S"
        (org-latex-preview '(16))))))

(map! :leader :desc "Page column (olivetti)" "t o" #'olivetti-mode)

;;; ── LaTeX ───────────────────────────────────────────────────────────────
;; Previews don't need ulem (strike-through), and it isn't always installed
;; (Arch: texlive-plaingeneric); without it every preview fails.
(after! ox-latex
  (setq org-latex-default-packages-alist
        (mapcar (lambda (pkg)
                  (if (equal (nth 1 pkg) "ulem") (list (nth 0 pkg) (nth 1 pkg) nil) pkg))
                org-latex-default-packages-alist)))

;; Math shows rendered, and turns back into source while the cursor is in it.
(use-package! org-fragtog
  :if (locate-library "org-fragtog")
  :hook (org-mode . org-fragtog-mode))

;;; ── Mermaid ─────────────────────────────────────────────────────────────
;; #+begin_src mermaid :file img/x.png, then C-c C-c draws it inline (mmdc).
(use-package! ob-mermaid
  :if (locate-library "ob-mermaid")
  :defer t
  :init
  (after! org
    (setq ob-mermaid-cli-path (or (executable-find "mmdc") "mmdc"))))

;;; ── One toggle for all of it ────────────────────────────────────────────
;; `org-modern-mode' alone only covers stars, labels, tables and blocks; this
;; flips everything above in the current buffer: raw text in a monospaced
;; code buffer, or the document view.
(defvar-local +my/org-raw-cookies nil
  "Face remappings that undo the heading sizes while the buffer is raw.")

(defun +my/org-pretty-toggle ()
  "Toggle the document look of this org buffer (org-modern, prose font, page
column, hidden markers, entities, heading sizes, inline images, LaTeX)."
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "Not an org buffer"))
  (let ((pretty (not +my/org-raw-cookies)))
    (if pretty
        ;; → raw
        (progn
          (dolist (face '(org-document-title org-level-1 org-level-2 org-level-3
                          org-level-4 org-level-5 org-level-6 org-level-7 org-level-8))
            (push (face-remap-add-relative face :height 1.0) +my/org-raw-cookies))
          (when (bound-and-true-p org-modern-mode) (org-modern-mode -1))
          (when (bound-and-true-p org-appear-mode) (org-appear-mode -1))
          (when (bound-and-true-p mixed-pitch-mode) (mixed-pitch-mode -1))
          (when (bound-and-true-p olivetti-mode) (olivetti-mode -1))
          (when (bound-and-true-p org-fragtog-mode) (org-fragtog-mode -1))
          (setq-local org-hide-emphasis-markers nil
                      org-pretty-entities nil
                      line-spacing nil
                      display-line-numbers display-line-numbers-type)
          (org-remove-inline-images)
          (org-clear-latex-preview))
      ;; → pretty
      (mapc #'face-remap-remove-relative +my/org-raw-cookies)
      (setq +my/org-raw-cookies nil)
      (kill-local-variable 'org-hide-emphasis-markers)
      (kill-local-variable 'org-pretty-entities)
      (org-modern-mode 1)
      (when (fboundp 'org-appear-mode) (org-appear-mode 1))
      (when (fboundp 'org-fragtog-mode) (org-fragtog-mode 1))
      (+my/org-page-h)
      (org-display-inline-images)
      (ignore-errors (org-latex-preview '(16))))
    (org-restart-font-lock)
    (message "Org: %s view" (if pretty "raw" "document"))))

(map! :leader :desc "Org: raw / document view" "t O" #'+my/org-pretty-toggle)
