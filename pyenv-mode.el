;;; pyenv-mode.el --- Integrate pyenv with python-mode

;; Copyright (C) 2014-2016 by Artem Malyshev

;; Author: Artem Malyshev <proofit404@gmail.com>
;; URL: https://github.com/proofit404/pyenv-mode
;; Version: 0.1.0
;; Package-Requires: ((emacs "25.1") (pythonic "0.1.0"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program. If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; See the README for more details.

;;; Code:

(require 'pythonic)

(defgroup pyenv nil
  "Pyenv virtualenv integration with python mode."
  :group 'languages)

(defcustom pyenv-mode-mode-line-format
  '(:eval
    (when (pyenv-mode-version)
      (concat "Pyenv:" (pyenv-mode-version) " ")))
  "How `pyenv-mode' will indicate the current python version in the mode line."
  :group 'pyenv)

(defun pyenv-mode-version ()
  "Return currently active pyenv version."
  (getenv "PYENV_VERSION"))

(defun pyenv-mode-root ()
  "Pyenv installation path."
  (replace-regexp-in-string "\n" "" (shell-command-to-string "pyenv root")))

(defun pyenv-mode-init-environment ()
  "Initialize pyenv environment in Emacs."
  (let ((pyenv-root (pyenv-mode-root)))
    (when pyenv-root
      (setenv "PYENV_ROOT" pyenv-root)
      (setenv "PATH" (concat pyenv-root "/shims:" (getenv "PATH")))
      (setenv "PYENV_VERSION" (replace-regexp-in-string "\n" "" (shell-command-to-string "pyenv version-name"))))))

(defun pyenv-mode-full-path (version)
  "Return full path for VERSION."
  (unless (string= version "system")
    (concat (pyenv-mode-root) "/versions/" version)))

(defun pyenv-mode-versions ()
  "List installed python versions."
  (let ((versions (shell-command-to-string "pyenv versions --bare")))
    (cons "system" (mapcar (lambda (v) (string-trim v))
                           (split-string versions "\n" t)))))

(defun pyenv-mode-read-version ()
  "Read virtual environment from user input."
  (completing-read "Pyenv: " (pyenv-mode-versions)))

(defun pyenv-mode-find-version (partial-version)
  "Find the best matching version for PARTIAL-VERSION using pattern matching."
  (let ((versions (pyenv-mode-versions))
        (trimmed-partial (string-trim partial-version)))
    (or
     ;; First try exact match
     (car (member trimmed-partial versions))
     ;; Then try pattern matching for partial versions (e.g., "3.11" matches "3.11.14")
     (car (cl-remove-if-not
           (lambda (version)
             (or (string-prefix-p (concat trimmed-partial ".") version)
                 (string-prefix-p (concat trimmed-partial "-") version)))
           versions))
     ;; If still no match, try using pyenv's version resolution
     (let ((resolved (ignore-errors
                       (string-trim
                        (shell-command-to-string
                         (format "pyenv version-name %s" (shell-quote-argument trimmed-partial)))))))
       (if (and resolved
                (> (length resolved) 0)
                (member resolved versions))
           resolved
         ;; Last resort: return the original version
         trimmed-partial)))))

;;;###autoload
(defun pyenv-mode-set (version)
  "Set python shell VERSION."
  (interactive (list (pyenv-mode-read-version)))
  (let ((full-version (pyenv-mode-find-version version)))
    (pythonic-activate (pyenv-mode-full-path full-version))
    (setenv "PYENV_VERSION" full-version)
    (force-mode-line-update)))

;;;###autoload
(defun pyenv-mode-unset ()
  "Unset python shell version."
  (interactive)
  (pythonic-deactivate)
  (setenv "PYENV_VERSION")
  (force-mode-line-update))

(defvar pyenv-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-s") 'pyenv-mode-set)
    (define-key map (kbd "C-c C-u") 'pyenv-mode-unset)
    map)
  "Keymap for pyenv-mode.")

;;;###autoload
(define-minor-mode pyenv-mode
  "Minor mode for pyenv interaction.

\\{pyenv-mode-map}"
  :global t
  :lighter ""
  :keymap pyenv-mode-map
  (if pyenv-mode
      (if (executable-find "pyenv")
          (progn
            (pyenv-mode-init-environment)
            (add-to-list 'mode-line-misc-info pyenv-mode-mode-line-format))
        (error "pyenv-mode: pyenv executable not found."))
    (setq mode-line-misc-info
          (delete pyenv-mode-mode-line-format mode-line-misc-info))))

(provide 'pyenv-mode)

;;; pyenv-mode.el ends here
