;;; asd-blog.el --- Stuff for blogging
;;
;; Author: Anders Dalskov
;; Copyright: (C) 2017, Anders Dalskov, all rights reserved.
;;
;;; Commentary:
;;
;; Settings and so on, that enables me to blog using Emacs. Inspired
;; by https://ogbe.net/blog/blogging_with_org.html
;;
;;; Code:

(require 'htmlize)
(require 'ox-publish)
(require 'ox-html)
(require 'url-util)
(require 'cl-lib) ;; for cl-intersect

(defvar asd/blog/navbar-items
  '(("/" . "front")
    ("/posts/blog.html" . "blog")
    ("/contact.html" . "contact")
    ("/links.html" . "links")))

(defvar asd/blog/base-directory "~/Documents/blog/"
  "Base directory where the blog resides.")

;; Stop `org-publish' from polluting recentf-list
(advice-add
 #'org-publish
 :around
 #'(lambda (f &rest args)
     (recentf-mode -1)
     (apply f args)
     (recentf-mode 1)))

;; Return a directory relative to `asd/blog/base-directory'
(defsubst asd/blog/base-dir (&rest subdirs)
  (let ((d asd/blog/base-directory))
    (dolist (sd subdirs d)
      (setq d (concat (file-name-as-directory d) sd)))))

;; Return a directory relative to the publication dir. The publication
;; dir is `asd/blog/base-directory'/www
(defsubst asd/blog/pub-dir (&rest subdirs)
  (apply #'asd/blog/base-dir `("www" ,@subdirs)))

;; Retrieve post creation time from the filename. Filenames (of posts)
;; are of the form `unix_timestamp'.org
(defun asd/blog/time-from-filename (filename &optional fmt-string)
  (let ((file (file-name-nondirectory filename))
	(fmt-string (or fmt-string "%F")))
    (let ((b (string-match "^[0-9].*\.org$" filename)))
      (when b
	(format-time-string
	 fmt-string
	 (string-to-number (file-name-sans-extension filename)))))))

;; Determine whether `file' is a proper posts, or the sitemap file.
(defsubst asd/blog/post-p (file)
  (multiple-value-bind (dir filename)
      (let ((file-list (split-string file "/")))
	(values (nth (- (length file-list) 2) file-list)
		(file-name-base (nth (1- (length file-list)) file-list))))
    (and (string= dir "posts")
	 (not (string= filename "blog")))))

;; Construct the postable (the thing at the bottom).
(defun asd/blog/postamble (options)
  (with-temp-buffer
    (insert "<hr>")
    ;; Author is sometimes nil (e.g., sitemap) so don't include it in that case.
    (let* ((file (plist-get options :input-file))
	   (author (car (plist-get options :author)))
	   (pub-time (when (asd/blog/post-p file) (asd/blog/time-from-filename file))))
      (when author
	(insert (format "<p class=\"author\">Author: %s</p>" author)))
      (insert (format-time-string "<p class=\"date\">Last modified: %Y-%m-%d %a %H:%M</p>"))
      (when pub-time
	(insert (format "<p class=\"date\">Published: %s</p>" pub-time)))
      (buffer-string))))

;; Construct the preable (the thing at the top).
(defun asd/blog/preamble (options)
  (with-temp-buffer
    (insert "<ul>")
    (dolist (it asd/blog/navbar-items)
      (insert (format "<li class=\"nav-item\"><a href=\"%s\">%s</a></li>" (car it) (cdr it))))
    (insert "</ul><hr>")
    (buffer-string)))

;; Retrieve the post preview.
(defun asd/blog/get-preview (file)
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (let ((b (1+ (re-search-forward "^#\\+BEGIN_PREVIEW$")))
	  (e (progn (re-search-forward "^#\\+END_PREVIEW$")
		    (match-beginning 0))))
      (buffer-substring b e))))

;; Construct sitemap file.
(defun asd/blog/sitemap (project &optional sitemap-fn)
  (let* ((project-plist (cdr project))
	 (dir (file-name-as-directory (plist-get project-plist :base-directory)))
	 (sitemap-fn (concat dir (or sitemap-fn "sitemap.org")))
	 (visiting (find-buffer-visiting sitemap-fn))
	 (localdir (file-name-directory dir))
	 (files (nreverse (org-publish-get-base-files project)))
	 file sitemap-buffer)
    (with-current-buffer
	(let ((org-inhibit-startup t))
	  (setq sitemap-buffer (or visiting (find-file sitemap-fn))))
      (erase-buffer)
      (insert "#+TITLE: " (plist-get project-plist :sitemap-title) "\n\n")
      (while (setq file (pop files))
	(let ((fn (file-name-nondirectory file)))
	  (unless (equal (file-truename sitemap-fn) (file-truename file))
	    (let ((title (org-publish-format-file-entry "%t" file project-plist))
		  (pub-date (asd/blog/time-from-filename file))
		  (preview (asd/blog/get-preview file)))
	      (message "filename from sitemap: %s (%s)" fn title)
	      (insert "* [[file:" fn "][" title "]] \n")
	      (insert preview "\n")
	      (insert "Posted: " pub-date ".\n\n")
	      (unless (null files)
		(insert "----------\n"))))))
      (save-buffer))
    (or visiting (kill-buffer sitemap-buffer))))

;;; This is currently needed. Org ignores project settings. Options
;;; seem to do fuck-all (besides setting the path...)
(setq org-html-mathjax-options '((path "/res/mathjax/MathJax.js?config=TeX-AMS-MML_HTMLorMML")
				 (scale "100") (align "left") (indent "2em") (mathml nil))
      org-html-mathjax-template "<script type=\"text/javascript\" src=\"%PATH\"></script>")

(setq org-publish-project-alist
      `(("blog"
	 :components ("blog-posts" "blog-image" "blog-video" "blog-static"))
	("blog-posts" ;; posts
	 :base-directory ,(asd/blog/base-dir "posts")
	 :publishing-directory ,(asd/blog/pub-dir "posts")
	 :base-extension "org"
	 :recursive t
	 :htmlized-source t

	 :with-author t
	 :with-date t
	 :with-toc nil
	 :with-creator nil

	 :html-doctype "html5"
	 :html-html5-fancy t
	 :html-postamble asd/blog/postamble
	 :html-preamble asd/blog/preamble
	 :html-head "<link rel=\"stylesheet\" href=\"/res/style.css\" type=\"text/css\"/>"

	 ;; :html-mathjax-options ,asd/blog/mathjax-options
	 ;; :html-mathjax-template "<script type=\"text/javascript\" src=\"%PATH\"></script>"

	 :headline-levels 4
	 :todo-keywords nil
	 :section-numbers nil

	 ;; sitemap stuff
	 :auto-sitemap t
	 :sitemap-filename "blog.org"
	 :sitemap-title "Latests posts"
	 :sitemap-date-format "%d-%m-%Y"
	 :sitemap-sort-files anti-chronologically
	 :sitemap-function asd/blog/sitemap

	 :publishing-function org-html-publish-to-html)

	("blog-static" ;; contact, links, and so on
	 :base-directory ,(asd/blog/base-dir)
	 :publishing-directory ,(asd/blog/pub-dir)
	 :base-extension "org"
	 :recursive t
	 :htmlized-source t

	 :with-author nil
	 :with-date t
	 :with-toc nil
	 :with-creator nil
	 :headline-levels 4
	 :todo-keywords nil
	 :section-numbers nil

	 :html-doctype "html5"
	 :html-html5-fancy t
	 :html-postamble asd/blog/postamble
	 :html-preamble asd/blog/preamble
	 :html-head "<link rel=\"stylesheet\" href=\"/res/style.css\" type=\"text/css\"/>"

	 :publishing-function org-html-publish-to-html)

	("blog-image" ;; images
	 :base-directory ,(asd/blog/base-dir "img")
	 :publishing-directory ,(asd/blog/pub-dir "img")
	 :base-extension ".*" ;; TODO: restrict
	 :publishing-function org-publish-attachment
	 :recursive t)

	("blog-video" ;; video
	 :base-directory ,(asd/blog/base-dir "vid")
	 :publishing-directory ,(asd/blog/pub-dir "vid")
	 :base-extension ".*" ; TODO: restrict
	 :publishing-function org-publish-attachment
	 :recursive t)
	 ))

;;; Here's some helper functions and whatnot

;; Characters that does not screw with org-mode
(defvar asd/blog/valid-title-chars-re "[a-zA-Z0-9 /\.()\+?!{}\-,=\"']")

;; Determine whether or not `title' is valid. It is, if it only
;; contains characters from `asd/blog/valid-title-chars-re'.
(defsubst asd/blog/valid-titlep (title)
  (zerop (length (replace-regexp-in-string asd/blog/valid-title-chars-re "" title))))

;; Function that creates a new blog post.
(defun asd/new-blog-post (title author)
  (interactive
   (let ((title (read-string "Title: " nil nil "Untitled"))
	 (author (read-string "Author:" "Anders Dalskov")))
     (list title author)))

  ;; Validate title
  (unless (asd/blog/valid-titlep title)
    (error "`%s' is not a valid title" title))

  ;; filenames are just a timestamp + .org
  (let ((filename (asd/blog/base-dir "posts/" (format-time-string "%s.org"))))
    (let ((buf (find-file-noselect filename)))
      (when buf
	(with-current-buffer buf
	  (insert
	   (format "#+TITLE: %s
#+AUTHOR: %s
#+BEGIN_PREVIEW

#+END_PREVIEW"
		   title author))
	  (forward-line -1))
	(switch-to-buffer buf)))))

(provide 'asd-blog)
;;; asd-blog.el ends here
