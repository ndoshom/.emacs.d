;;; -*- lexical-binding: t -*-

;; -----------------------------------------------------------------
;; Custom File & UI Elements Settings
;; -----------------------------------------------------------------
(setq custom-file (locate-user-emacs-file "custom.el"))
(load custom-file t)

(scroll-bar-mode -1)    ; Disable visible scrollbar
(tool-bar-mode -1)      ; Disable toolbar
(tooltip-mode -1)
(menu-bar-mode -1)      ; Disable menubar


(setq visible-bell nil)           ; Set up the visible bell
(setq inhibit-startup-message t)  ; Skip default startup splash
(setq mouse-drag-copy-region t)   ; Copy on drag-select with mouse

;; -----------------------------------------------------------------
;; Typography (Font Settings)
;; -----------------------------------------------------------------
(set-face-attribute 'default nil :font "JetBrainsMono Nerd Font" :height 150) 

;; -----------------------------------------------------------------
;; Package Repository & use-package Bootstrap
;; -----------------------------------------------------------------
(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;; CRITICAL FIX: Bypass expired internal ELPA GPG security keys 
;; to allow package downloads without throwing "package unavailable" blocks.
(setq package-check-signature nil)

;; Automatically download remote indices if local index cache is empty
(unless package-archive-contents
  (package-refresh-contents))

;; Automatically download use-package if it isn't on your machine yet
(unless (package-installed-p 'use-package)
  (package-install 'use-package))

(eval-when-compile
  (require 'use-package))

;; -----------------------------------------------------------------
;; Doom Themes Configuration
;; -----------------------------------------------------------------
(use-package doom-themes
  :ensure t
  :config
  ;; Global settings
  (setq doom-themes-enable-bold t    ; Enable bold fonts universally
        doom-themes-enable-italic t) ; Enable italic fonts universally
  (load-theme 'doom-one t)
  
  ;; Corrects and improves org-mode's native block fontification
  (doom-themes-org-config))

;; -----------------------------------------------------------------
;; Completion Stack (Vertico, Marginalia, Savehist, Orderless)
;; -----------------------------------------------------------------
(use-package vertico
  :ensure t
  :init
  (vertico-mode 1))

(use-package marginalia
  :ensure t
  :config
  (marginalia-mode 1))

(use-package savehist
  :ensure nil ; Built-in core package, no download needed
  :init
  (savehist-mode 1))

(use-package orderless
  :ensure t
  :config
  (setq completion-styles '(orderless basic))
  (setq completion-category-defaults nil))

(use-package delsel
  :ensure nil
  :config
  (delete-selection-mode 1))

;; -----------------------------------------------------------------
;; Consult (enhanced search/navigation commands)
;; -----------------------------------------------------------------
(use-package consult
  :ensure t
  :bind (("C-s" . consult-line)            ; Search current buffer
         ("C-x b" . consult-buffer)        ; Enhanced buffer switching
         ("M-y" . consult-yank-pop)        ; Search kill-ring
         ("M-g g" . consult-goto-line)     ; Go to line
         ("M-g M-g" . consult-goto-line)
         ("M-g i" . consult-imenu)         ; Jump to symbol/heading
         ("M-s r" . consult-ripgrep)))     ; Project-wide grep (needs ripgrep installed)

;; -----------------------------------------------------------------
;; Embark (contextual actions on candidates / point)
;; -----------------------------------------------------------------
(use-package embark
  :ensure t
  :bind (("C-." . embark-act)         ; Act on thing at point
         ("C-;" . embark-dwim)        ; Do-what-I-mean default action
         ("C-h B" . embark-bindings)) ; Alternative to describe-bindings
  :init
  ;; Show a nicer key-prompt when embark is waiting for input
  (setq prefix-help-command #'embark-prefix-help-command))

;; Glue so Embark and Consult play nicely together (e.g. embark-export
;; from a consult-grep buffer, live preview in embark collect, etc.)
(use-package embark-consult
  :ensure t
  :after (embark consult)
  :hook
  (embark-collect-mode . consult-preview-at-point-mode))

;; -----------------------------------------------------------------
;; Tree-sitter: grammar sources + auto-install
;; -----------------------------------------------------------------
(setq treesit-language-source-alist
      '((c        . ("https://github.com/tree-sitter/tree-sitter-c"))
        (cpp      . ("https://github.com/tree-sitter/tree-sitter-cpp"))
        (rust     . ("https://github.com/tree-sitter/tree-sitter-rust"))))
        ;; Odin has no official/widely-used tree-sitter grammar as of
        ;; writing — see note below.

;; Install any grammar from the list above that isn't already present.
;; Run this once (or call `treesit-install-language-grammar` manually
;; per-language if you'd rather control it interactively).
(dolist (lang '(c cpp rust))
  (unless (treesit-language-available-p lang)
    (treesit-install-language-grammar lang)))

;; -----------------------------------------------------------------
;; Remap legacy major modes to their tree-sitter equivalents
;; -----------------------------------------------------------------
(setq major-mode-remap-alist
      '((c-mode    . c-ts-mode)
        (c++-mode  . c++-ts-mode)
        (rust-mode . rust-ts-mode)))

;; -----------------------------------------------------------------
;; Eglot (built-in LSP client) — C, Rust support via -ts-mode
;; -----------------------------------------------------------------
(use-package eglot
  :ensure nil ; Built-in as of Emacs 29+
  :hook ((c-ts-mode c++-ts-mode rust-ts-mode) . eglot-ensure)
  :config
  (add-to-list 'eglot-server-programs
               '((c-ts-mode c++-ts-mode) . ("clangd")))
  (add-to-list 'eglot-server-programs
               '(rust-ts-mode . ("rust-analyzer"))))

;; -----------------------------------------------------------------
;; vterm (full terminal emulator, native-compiled C module)
;; -----------------------------------------------------------------
(use-package vterm
  :ensure t
  :commands vterm
  :bind ("C-c t" . vterm)
  :config
  (setq vterm-shell "/bin/bash")         ; Force bash regardless of $SHELL
  (setq vterm-max-scrollback 10000)
  (setq vterm-timer-delay 0.01)
  (setq vterm-kill-buffer-on-exit t)
  (add-to-list 'display-buffer-alist
               '("\\*vterm\\*"
                 (display-buffer-in-side-window)
                 (side . bottom)
                 (window-height . 0.3))))

;; -----------------------------------------------------------------
;; Auto-evaluate init.el on save
;; -----------------------------------------------------------------
(defun my/eval-init-on-save ()
  "If the current buffer is `user-init-file', evaluate it after save
and refresh the keybindings note."
  (when (and (buffer-file-name)
             (equal (file-truename (buffer-file-name))
                    (file-truename user-init-file)))
    (load-file user-init-file)
    (message "init.el reloaded")))

(add-hook 'after-save-hook #'my/eval-init-on-save)
;; -----------------------------------------------------------------
;; Projectile (project-aware navigation & commands)
;; -----------------------------------------------------------------
(use-package projectile
  :ensure t
  :init
  (projectile-mode 1)
  :bind-keymap
  ("C-c p" . projectile-command-map)
  :config
  (setq projectile-completion-system 'default)
  (setq projectile-project-search-path '("~/playground" ".emacs.d"))
  (setq projectile-switch-project-action #'projectile-dired)
  ;; Recognize jj-native repos (.jj dir, no colocated .git) as projects
  (add-to-list 'projectile-project-root-files-bottom-up ".jj"))

;; -----------------------------------------------------------------
;; Majutsu (Magit-style interface for Jujutsu)
;; -----------------------------------------------------------------
(use-package majutsu
  :vc (:url "https://github.com/0WD0/majutsu") ; Emacs 29+ package-vc install
  :bind ("C-c j" . majutsu)) ; Launch jj log/status interface

;; -----------------------------------------------------------------
;; Denote (simple note-taking with structured file naming)
;; -----------------------------------------------------------------
(use-package denote
  :ensure t
  :init
  (setq denote-directory (expand-file-name "~/notes")) ; adjust to your actual notes dir
  :config
  (setq denote-known-keywords '("emacs" "linux" "programming" "accounting"))
  (setq denote-infer-keywords t)      ; allow keywords not in the list above
  (setq denote-sort-keywords t)       ; keep keywords alphabetized in filenames
  (setq denote-file-type nil)         ; nil = org, or 'markdown-yaml, 'text, etc.
  :bind (("C-c n n" . denote)                  ; Create a new note
         ("C-c n f" . denote-open-or-create)   ; Find or create a note by title
         ("C-c n r" . denote-rename-file)      ; Rename file using denote scheme
         ("C-c n l" . denote-link)             ; Insert a link to another note
         ("C-c n b" . denote-backlinks)))      ; Show backlinks to current note

