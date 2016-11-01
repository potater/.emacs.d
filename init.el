(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(eval-when-compile
  (require 'use-package))
(require 'bind-key)

;;;; Themes, fonts and other stuff related to looks and default behaviour
(when (eq window-system 'x)
  (set-face-attribute 'default nil :family "DejaVu Sans Mono" :height 90)
  (load-theme 'leuven t))

(tooltip-mode -1)
(tool-bar-mode -1)
(menu-bar-mode -1)
(scroll-bar-mode -1)
(blink-cursor-mode 0)
(line-number-mode t)
(column-number-mode t)
(setq ring-bell-function 'ignore
      inhibit-splash-screen t
      initial-scratch-message nil
      scroll-step 1)
(setq display-time-24hr-format t
      display-time-day-and-date t
      display-time-default-load-average nil)
(display-time)
(fset 'yes-or-no-p 'y-or-n-p)

(use-package iso-transl) ;; fix dead keys

;; Place backups in a specific directory
(setq backup-by-copying t
      backup-directory-alist '(("." . "~/.emacs_backups"))
      delete-old-versions t
      kept-new-versions 6
      kept-old-versions 2
      version-control t)

(use-package uniquify
  :config
  (setq uniquify-buffer-name-style 'post-forward))

(use-package smart-mode-line
  :init
  (setq sml/no-confirm-load-theme t
	sml/theme 'light)
  :config
  (sml/setup)
  (mapc (lambda (x) (add-to-list 'sml/replacer-regexp-list x))
  	'(("^~/Code/" ":CODE:")
	  ("^~/.config/" ":CONF:")
	  ("^~/.emacs.d/" ":EMACS:")
	  ("^~/Documents/" ":DOC:")
	  ("^~/Documents/org/" ":ORG:")
	  ("^~/Documents/uni" ":UNI:"))))

(use-package ansi-color
  :init
  (add-hook 'shell-mode-hook 'ansi-color-for-comint-mode-on))

;;;; Misc functions
(defun recreate-scratch ()
  "Recreate scratch buffer"
  (interactive)
  (switch-to-buffer (get-buffer-create "*scratch*"))
  (lisp-interaction-mode))

(defun kill-all-buffers ()
  (interactive)
  (when (y-or-n-p "Kill all buffers?")
    (mapc 'kill-buffer (buffer-list))
    (delete-other-windows)
    (recreate-scratch)))

;; (defmacro yas-minor-mode-for (mode)
;;   `(lambda ()
;;      (yas-reload-all)
;;      (add-hook ',mode 'yas-minor-mode)))

;;;; Keybinds
(put 'upcase-region 'disabled nil)

(bind-key "C-x K" #'kill-all-buffers)

;;;; Package configs

(use-package yasnippet
  :config
  (yas-reload-all))

(use-package tex
  :init
  (setq TeX-auto-save t
	TeX-parse-self t
	ispell-list-command "--list")
  (setq-default TeX-master nil)
  (add-hook 'LaTeX-mode-hook 'turn-on-reftex)
  (setq reftex-plug-into-AUCTeX t)
  (add-hook 'LaTeX-mode-hook 'visual-line-mode)
  (add-hook 'LaTeX-mode-hook 'turn-on-flyspell)
  (add-hook 'LaTeX-mode-hook 'LaTeX-math-mode))

(use-package cc-mode
  :mode (("\\.c\\'" . c-mode)
	 ("\\.h\\'" . c-mode))
  :bind ([ret] . newline-and-indent) 
  :init
  (add-hook 'c-mode-hook (lambda () (c-set-style "linux")))
  (add-hook 'c-mode-hook 'yas-minor-mode))

(use-package python
  :mode ("\\.py\\'" . python-mode)
  :bind (:map python-mode-map
	      ("C-c C-q" . hs-toggle-hiding))
  :init
  (add-hook 'python-mode-hook (lambda () (hs-minor-mode 1)))
  (add-hook 'python-mode-hook 'ansi-color-for-comint-mode-on)
  (add-hook 'python-mode-hook 'jedi:setup)
  (add-hook 'python-mode-hook 'yas-minor-mode)
  (setq python-indent 4)
  ;; FIXME: https://debbugs.gnu.org/cgi/bugreport.cgi?bug=24401
  (setq python-shell-interpreter "python2"))

(use-package helm
  :bind (("M-x" . helm-M-x)
	 ("M-y" . helm-show-kill-ring)
	 ("C-x b" . helm-mini)
	 ("C-x C-f" . helm-find-files)
	 :map helm-map
	 ([tab] . helm.execute-persistent-action)
	 ("C-z" . helm-select-action))
  :init
  (setq helm-split-window-in-side-p t
	helm-M-x-fuzzy-match t
	helm-buffers-fuzzy-matching t
	helm-recentf-fuzzy-match t))

(use-package elfeed
  :load-path ("lisp/" "super-secret-directory/")
  :bind (("C-x w" . elfeed)
	 :map elfeed-show-mode-map
	 ("n" . scroll-up-line)
	 ("p" . scroll-down-line)
	 ("C-p" . elfeed-show-next)
	 ("C-n" . elfeed-show-prev)
	 :map elfeed-search-mode-map
	 ("x" . elfeed-open-entry-in-mpv))
  :init
  (setq elfeed-curl-program-name "curl"
	elfeed-use-curl t)
  (defun elfeed-open-entry-in-mpv ()
    (interactive)
    (let* ((entry (elfeed-search-selected :single))
	   (url (elfeed-entry-link entry)))
      (elfeed-search-untag-all 'unread)
      (start-process "mpv-emacs" nil "mpv" url)))
  :config
  (use-package user-feeds))

(use-package dired
  :bind (:map dired-mode-map
	      ([backspace] . dired-up-directory)))

(use-package tramp
  :init
  (setq tramp-default-method "ssh"))

(use-package magit
  :bind ("C-x g" . magit-status))

(use-package org
  :bind ("C-c a" . org-agenda)
  :init
  (setq org-log-done t
	org-agenda-files (directory-files "~/Documents/org/agenda files/")
	org-todo-keywords '((sequence "TODO(t)" "|" "DONE(d)")
			    (sequence "WAITING(w)" "|")
			    (sequence "|" "CANCELED(c)"))
	org-todo-keyword-faces '(("WAITING" . "yellow")
				 ("CANCELED" . (:foreground "grey" :weight "bold")))))
	      

