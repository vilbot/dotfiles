(require 'package)
(add-to-list 'package-archives
             '("melpa" . "https://melpa.org/packages/") t)

(package-initialize)

(unless (package-installed-p 'evil)
  (package-install 'evil))
(unless (package-installed-p 'gruber-darker-theme)
  (package-install 'gruber-darker-theme))
(unless (package-installed-p 'perspective)
  (package-install 'perspective))
(unless (package-installed-p 'vertico)
  (package-install 'vertico))
(vertico-mode 1)

(unless (package-installed-p 'consult)
  (package-install 'consult))


(load-theme 'gruber-darker t)
(require 'evil)
(require 'perspective)

(evil-mode 1)
(persp-mode 1)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages '(consult evil gruber-darker-theme perspective vertico)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

(setq-default truncate-lines t)
(show-paren-mode -1)
(blink-cursor-mode -1)
(set-face-attribute 'default nil :family "Liberation Mono" :height 110)
(mapc (lambda (face)
	(set-face-attribute face nil :weight 'normal :slant 'normal))
      (face-list))

(define-key evil-normal-state-map (kbd "SPC TAB n") 'persp-next)
(define-key evil-normal-state-map (kbd "SPC TAB p") 'persp-prev)
(define-key evil-normal-state-map (kbd "SPC TAB s") 'persp-switch)
(define-key evil-normal-state-map (kbd "SPC TAB k") 'persp-kill)

(define-key evil-normal-state-map (kbd "SPC f f") 'consult-find)
(define-key evil-normal-state-map (kbd "SPC b b") 'consult-buffer)
