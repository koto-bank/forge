;;; forge-pullreq.el --- Pullreq support          -*- lexical-binding: t -*-

;; Copyright (C) 2018-2020  Jonas Bernoulli

;; Author: Jonas Bernoulli <jonas@bernoul.li>
;; Maintainer: Jonas Bernoulli <jonas@bernoul.li>

;; Forge is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; Forge is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
;; or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
;; License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with Forge.  If not, see http://www.gnu.org/licenses.

;;; Code:

(require 'forge)
(require 'forge-post)
(require 'forge-topic)

;;; Faces

(defface forge-pullreq-diff-post-heading
  `((((class color) (background light))
     ,@(and (>= emacs-major-version 27) '(:extend t))
     :background "LightSalmon3")
    (((class color) (background dark))
     ,@(and (>= emacs-major-version 27) '(:extend t))
     :background "salmon4"))
  "Face used for diff post heading."
  :group 'magit-faces)

(defface forge-pullreq-diff-post-reply-heading
  `((((class color) (background light))
     :background "LightSkyBlue1")
    (((class color) (background dark))
     :background "SkyBlue4"))
  "Face used for diff reply post heading."
  :group 'magit-faces)

(defface forge-pullreq-diff-delimitation
  '((t :underline "salmon4" :extend t))
  "Face used for diff delimitation."
  :group 'magit-faces)

;;; Classes

(defclass forge-pullreq (forge-topic)
  ((closql-table         :initform pullreq)
   (closql-primary-key   :initform id)
   (closql-order-by      :initform [(desc number)])
   (closql-foreign-key   :initform repository)
   (closql-class-prefix  :initform "forge-")
   (id                   :initarg :id)
   (repository           :initarg :repository)
   (number               :initarg :number)
   (state                :initarg :state)
   (author               :initarg :author)
   (title                :initarg :title)
   (created              :initarg :created)
   (updated              :initarg :updated)
   (closed               :initarg :closed)
   (merged               :initarg :merged)
   (unread-p             :initarg :unread-p :initform nil)
   (locked-p             :initarg :locked-p)
   (editable-p           :initarg :editable-p)
   (cross-repo-p         :initarg :cross-repo-p)
   (base-ref             :initarg :base-ref)
   (base-repo            :initarg :base-repo)
   (head-ref             :initarg :head-ref)
   (head-user            :initarg :head-user)
   (head-repo            :initarg :head-repo)
   (milestone            :initarg :milestone)
   (body                 :initarg :body)
   (assignees            :closql-table (pullreq-assignee assignee))
   (project-cards) ; projectsCards
   (commits)
   (edits) ; userContentEdits
   (labels               :closql-table (pullreq-label label))
   (participants)
   (posts                :closql-class forge-pullreq-post)
   (versions             :closql-class forge-pullreq-version)
   (reactions)
   (review-requests      :closql-table (pullreq-review-request assignee))
   (reviews)
   (timeline)
   (marks                :closql-table (pullreq-mark mark))
   ;; We don't use these fields:
   ;; includesCreatedEdit (huh?),
   ;; lastEditedAt (same as updatedAt?),
   ;; publishedAt (same as createdAt?),
   ;; activeLockReason, additions, authorAssociation, (baseRefName), baseRefOid,
   ;; bodyHTML, bodyText, canBeRebased, changedFiles, closed, createdViaEmail,
   ;; databaseId, deletions, editor, (headRefName), headRefOid, mergeCommit,
   ;; mergeStateStatus, mergeable, merged, mergedBy, permalink,
   ;; potentialMergeCommit,, reactionGroups, resourcePath, revertResourcePath,
   ;; revertUrl, url, viewer{*}
   ))

(defclass forge-pullreq-post (forge-post)
  ((closql-table         :initform pullreq-post)
   (closql-primary-key   :initform id)
   (closql-order-by      :initform [(asc number)])
   (closql-foreign-key   :initform pullreq)
   (closql-class-prefix  :initform "forge-pullreq-")
   (id                   :initarg :id)
   (thread-id            :initarg :thread-id)
   (diff-p               :initarg :diff-p)
   (reply-to             :initarg :reply-to)
   (pullreq              :initarg :pullreq)
   (head-ref             :initarg :head-ref)
   (commit-ref           :initarg :commit-ref)
   (base-ref             :initarg :base-ref)
   (path                 :initarg :path)
   (old-line             :initarg :old-line)
   (new-line             :initarg :new-line)
   (number               :initarg :number)
   (author               :initarg :author)
   (created              :initarg :created)
   (updated              :initarg :updated)
   (body                 :initarg :body)
   (edits)
   (reactions)
   ;; We don't use these fields:
   ;; includesCreatedEdit (huh?),
   ;; lastEditedAt (same as updatedAt?),
   ;; publishedAt (same as createdAt?),
   ;; pullRequest (same as issue),
   ;; repository (use .pullreq.project),
   ;; authorAssociation, bodyHTML, bodyText, createdViaEmail,
   ;; editor, id, reactionGroups, resourcePath, url, viewer{*}
   ))

(defclass forge-pullreq-version (forge-object)
  ((closql-table         :initform pullreq-version)
   (closql-primary-key   :initform id)
   (closql-order-by      :initform [(desc id)])
   (closql-foreign-key   :initform pullreq)
   (closql-class-prefix  :initform "forge-pullreq-")
   (id                   :initarg :id)
   (pullreq              :initarg :pullreq)
   (head-ref             :initarg :head-ref)
   (base-ref             :initarg :base-ref)))

;;; Query

(cl-defmethod forge-get-repository ((post forge-pullreq-post))
  (forge-get-repository (forge-get-pullreq post)))

(cl-defmethod forge-get-topic ((post forge-pullreq-post))
  (forge-get-pullreq post))

(cl-defmethod forge-get-pullreq ((repo forge-repository) number)
  (closql-get (forge-db)
              (forge--object-id 'forge-pullreq repo number)
              'forge-pullreq))

(cl-defmethod forge-get-pullreq ((number integer))
  (when-let ((repo (forge-get-repository t)))
    (forge-get-pullreq repo number)))

(cl-defmethod forge-get-pullreq ((id string))
  (closql-get (forge-db) id 'forge-pullreq))

(cl-defmethod forge-get-pullreq ((post forge-pullreq-post))
  (closql-get (forge-db)
              (oref post pullreq)
              'forge-pullreq))

(cl-defmethod forge-ls-pullreqs ((repo forge-repository) &optional type)
  (forge-ls-topics repo 'forge-pullreq type))

;;; Utilities

(defun forge-read-pullreq (prompt &optional type)
  (when (eq type t)
    (setq type (if current-prefix-arg nil 'open)))
  (let* ((default (forge-current-pullreq))
         (repo    (forge-get-repository (or default t)))
         (format  (lambda (topic)
                    (format "%s  %s"
                            (oref topic number)
                            (oref topic title))))
         (choices (forge-ls-pullreqs repo type))
         (choice  (magit-completing-read
                   prompt
                   (mapcar format choices)
                   nil nil nil nil
                   (and default
                        (funcall format default)))))
    (and (string-match "\\`\\([0-9]+\\)" choice)
         (string-to-number (match-string 1 choice)))))

(defun forge--pullreq-branch (pullreq &optional confirm-reset)
  (with-slots (head-ref number cross-repo-p editable-p) pullreq
    (let ((branch head-ref)
          (branch-n (format "pr-%s" number)))
      (when (or (and cross-repo-p (not editable-p))
                ;; Handle deleted GitHub pull-request branch.
                (not branch)
                ;; Such a branch name would be invalid.  If we encounter
                ;; this, then it means that we are dealing with a Gitlab
                ;; pull-request whose source branch has been deleted.
                (string-match-p ":" branch)
                ;; These are usually the target, not source, of a pr.
                (member branch '("master" "next" "maint")))
        (setq branch branch-n))
      (when (and confirm-reset (magit-branch-p branch))
        (when (magit-branch-p branch)
          (if (string-prefix-p "pr-" branch)
              (unless (y-or-n-p
                       (format "Branch %S already exists.  Reset it? " branch))
                (user-error "Abort"))
            (pcase (read-char-choice
                    (format "A branch named %S already exists.

This could be because you checked out this pull-request before,
in which case resetting might be the appropriate thing to do.

Or the contributor worked directly on their version of a branch
that also exists on the upstream, in which case you probably
should not reset because you would end up resetting your version.

Or you are trying to checkout a pull-request that you created
yourself, in which case you probably should not reset either.

  [r]eset existing %S branch
  [c]reate new \"pr-%s\" branch instead
  [a]bort" branch branch number) '(?r ?c ?a))
              (?r)
              (?c (setq branch branch-n)
                  (when (magit-branch-p branch)
                    (error "Oh no!  %S already exists too" branch)))
              (?a (user-error "Abort"))))
          (message "")))
      branch)))

(defun forge--pullreq-ref (pullreq)
  (let ((ref (format "refs/pullreqs/%s" (oref pullreq number))))
    (and (magit-rev-verify ref) ref)))

(cl-defmethod forge-get-url ((pullreq forge-pullreq))
  (forge--format pullreq 'pullreq-url-format))

;;; Sections

(defun forge-current-pullreq ()
  (or (forge-pullreq-at-point)
      (and (derived-mode-p 'forge-topic-mode)
           (forge-pullreq-p forge-buffer-topic)
           forge-buffer-topic)
      (and (derived-mode-p 'forge-topic-list-mode)
           (let ((topic (forge-get-topic (tabulated-list-get-id))))
             (and (forge-pullreq-p topic)
                  topic)))))

(defun forge-pullreq-at-point ()
  (or (magit-section-value-if 'pullreq)
      (when-let ((post (magit-section-value-if 'post)))
        (cond ((forge-pullreq-p post)
               post)
              ((forge-pullreq-post-p post)
               (forge-get-pullreq post))))))

(defvar forge-pullreqs-section-map
  (let ((map (make-sparse-keymap)))
    (define-key map [remap magit-browse-thing] 'forge-browse-pullreqs)
    (define-key map [remap magit-visit-thing]  'forge-list-pullreqs)
    (define-key map (kbd "C-c C-n")            'forge-create-pullreq)
    map))

(defvar forge-pullreq-section-map
  (let ((map (make-sparse-keymap)))
    (define-key map [remap magit-browse-thing] 'forge-browse-pullreq)
    (define-key map [remap magit-visit-thing]  'forge-visit-pullreq)
    map))

(defvar forge-pullreq-diff-section-map
  (let ((map (make-sparse-keymap)))
    (define-key map [remap magit-browse-thing] 'forge-browse-pullreq)
    (define-key map [remap magit-visit-thing]  'forge-show-pullreq-diff)
    map))

(defvar-local forge--pullreq-version nil)
(defvar-local forge--pullreq-commit nil)
(defvar-local forge--pullreq-buffer nil)

(defun forge-insert-pullreqs ()
  "Insert a list of mostly recent and/or open pull-requests.
Also see option `forge-topic-list-limit'."
  (when-let ((repo (forge-get-repository nil)))
    (unless (oref repo sparse-p)
      (forge-insert-topics "Pull requests"
                           (forge-ls-recent-topics repo 'pullreq)
                           (forge--topic-type-prefix repo 'pullreq)))))

(defun forge--insert-pullreq-commits (pullreq)
  (when-let ((ref (forge--pullreq-ref pullreq)))
    (magit-insert-section-body
      (cl-letf (((symbol-function #'magit-cancel-section) (lambda ())))
        (magit-insert-log (format "%s..%s" (oref pullreq base-ref) ref)
                          magit-buffer-log-args)
        (magit-make-margin-overlay nil t)))))

(defun forge--filter-diff-posts-by-version (posts version)
  (let ((head (oref version head-ref))
        (base (oref version base-ref)))
    (cl-remove-if-not (lambda (post)
                        (with-slots (diff-p head-ref base-ref) post
                          (and diff-p
                               (string= head-ref head)
                               (string= base-ref base))))
                      posts)))

(defun forge--filter-diff-posts-by-commit (posts commit)
  (cl-remove-if-not (lambda (post)
                      (with-slots (diff-p commit-ref) post
                        (and diff-p (string= commit-ref commit))))
                    posts))

;;; Diff

(defun forge--pullreq-diff-goto-line (file line goto-from)
  (when-let* ((hunk (magit-diff--locate-hunk file line))
              (hunk-section (car hunk)))
    (with-slots (content from-range to-range) hunk-section
      (let* ((range (if goto-from from-range to-range))
             (start (car range))
             (cur-line start))
        (goto-char content)
        (while (not (= cur-line line))
          (forward-line)
          (unless (or (magit-section-value-if 'post)
                      (string-match-p (if goto-from "\\+" "-")
                                      (buffer-substring (point) (+ (point) 1))))
            (cl-incf cur-line)))))))

(defun forge--insert-pullreq-diff-posts (diff-posts)
  (let* ((inhibit-read-only t)
         (root-section magit-root-section))
    (dolist (post diff-posts)
      (with-slots (reply-to path old-line new-line number author created body) post
        (unless reply-to
          (save-excursion
            ;; goto to the line in diff
            (if (and old-line (or (not new-line)
                                  (not (= old-line new-line))))
                (forge--pullreq-diff-goto-line path old-line t)
              (forge--pullreq-diff-goto-line path new-line nil))
            (forward-line)
            ;; insert post
            (magit-insert-section section (post post)
              (oset section heading-highlight-face 'forge-pullreq-diff-post-heading)
              (forge--insert-section author created body
                                     'forge-pullreq-diff-post-heading)
              ;; insert replies of this post
              (forge--insert-replies diff-posts number
                                     'forge-pullreq-diff-post-reply-heading)
	      ;; insert delimitation line
	      (overlay-put (make-overlay (- (point) 1) (point))
			   'face 'forge-pullreq-diff-delimitation))
            (setq magit-root-section root-section)))))))

(defun forge--pullreq-diff-refresh ()
  (let* ((posts (oref forge-buffer-topic posts))
         (diff-posts (if forge--pullreq-commit
                         (forge--filter-diff-posts-by-commit
                          posts forge--pullreq-commit)
                       (forge--filter-diff-posts-by-version
                        posts forge--pullreq-version))))
    (forge--insert-pullreq-diff-posts diff-posts)
    (when (buffer-live-p forge--pullreq-buffer)
      (with-current-buffer forge--pullreq-buffer
        (magit-refresh)))))

(defun forge-show-pullreq-diff ()
  (interactive)
  (cl-multiple-value-bind (version commit)
      (magit-section-value-if 'pullreq-diff)
    (let ((topic forge-buffer-topic)
	  (pullreq-buffer (current-buffer))
	  (buf (if commit
		   (magit-revision-setup-buffer
		    commit (magit-show-commit--arguments) nil)
		 (with-slots (base-ref head-ref) version
		   (magit-diff-setup-buffer
		    (format "%s..%s" base-ref head-ref)
		    nil (magit-diff-arguments) nil)))))
      (with-current-buffer buf
	(setq forge--pullreq-version version)
	(setq forge--pullreq-commit commit)
	(setq forge--pullreq-buffer pullreq-buffer)
	(setq forge-buffer-topic topic)
	(add-hook 'magit-unwind-refresh-hook 'forge--pullreq-diff-refresh nil t)
	(magit-refresh)))))

(defun forge--insert-pullreq-diff-commits (version diff-commits diff-posts)
  (dolist (commit diff-commits)
    (cl-multiple-value-bind (id abbrev-id subject) commit
      (magit-insert-section (pullreq-diff (list version id))
        (let ((posts (forge--filter-diff-posts-by-commit diff-posts id)))
          (insert (concat (propertize abbrev-id 'face 'magit-hash)
                          (format " %-50s " subject)
                          (when posts
                            (propertize (format "(%d comments)" (length posts))
                                        'face 'magit-section-heading)))
                "\n")))))
    (insert "\n"))

(defun forge--insert-pullreq-versions (pullreq)
  (let ((posts (oref pullreq posts))
        (versions (reverse (oref pullreq versions)))
        (count 0))
    (dolist (version versions)
      (with-slots (base-ref head-ref) version
        (cl-incf count)
        (let* ((diff-commits (magit-git-lines "log" "--format=(\"%H\" \"%h\" \"%s\")"
                                              (format "%s..%s" base-ref head-ref)))
               (diff-posts (forge--filter-diff-posts-by-version posts version))
               (comments-nbr (format "(%d comments) " (length diff-posts)))
               (hide (not (eq count (length versions)))))
          ;; all the version section are collapsed except for the latest version
          (magit-insert-section (pullreq-diff (list version) hide)
            (magit-insert-heading (concat (if (= count (length versions))
                                              "Latest Version:  "
                                            (format "Version %d:  " count))
                                          (when diff-posts comments-nbr)))
            (forge--insert-pullreq-diff-commits version
                                                (mapcar #'read diff-commits)
                                                diff-posts)))))))

(cl-defmethod forge--insert-topic-contents :after ((pullreq forge-pullreq)
                                                   _width _prefix)
  (unless (oref pullreq merged)
    (magit-insert-heading)
    (forge--insert-pullreq-commits pullreq)))

(cl-defmethod forge--format-topic-id ((pullreq forge-pullreq) &optional prefix)
  (propertize (format "%s%s"
                      (or prefix (forge--topic-type-prefix pullreq))
                      (oref pullreq number))
              'font-lock-face (if (oref pullreq merged)
                                  'forge-topic-merged
                                'forge-topic-unmerged)))

(cl-defmethod forge--topic-type-prefix ((pullreq forge-pullreq))
  (if (forge--childp (forge-get-repository pullreq) 'forge-gitlab-repository)
      "!"
    "#"))

(defun forge-insert-assigned-pullreqs ()
  "Insert a list of open pull-requests that are assigned to you."
  (when-let ((repo (forge-get-repository nil)))
    (unless (oref repo sparse-p)
      (forge-insert-topics "Assigned pull requests"
                           (forge--ls-assigned-pullreqs repo)
                           (forge--topic-type-prefix repo 'pullreq)))))

(defun forge--ls-assigned-pullreqs (repo)
  (mapcar (lambda (row)
            (closql--remake-instance 'forge-pullreq (forge-db) row))
          (forge-sql
           [:select $i1 :from pullreq
            :join pullreq_assignee :on (= pullreq_assignee:pullreq pullreq:id)
            :join assignee         :on (= pullreq_assignee:id      assignee:id)
            :where (and (= pullreq:repository $s2)
                        (= assignee:login     $s3)
                        (isnull pullreq:closed))
            :order-by [(desc updated)]]
           (vconcat (closql--table-columns (forge-db) 'pullreq t))
           (oref repo id)
           (ghub--username repo))))

;;; _
(provide 'forge-pullreq)
;;; forge-pullreq.el ends here
