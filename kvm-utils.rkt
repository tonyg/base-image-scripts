#lang racket

(provide something-exists?
         delete-file*
         call-with-temporary-file

         xexpr-trim-whitespace
         string->xexpr/defaults

         clean-mac
         substitute

         run
         run/output
         with-silent-stderr

         run-virsh
         run-virsh/output

         domain-info

         list-domains
         all-domains
         running-domains

         image-info)

(require xml)
(require json)
(require rackunit)

;;---------------------------------------------------------------------------

(define (something-exists? path)
  (or (file-exists? path)
      (directory-exists? path)
      (link-exists? path)))

(define (delete-file* path)
  (with-handlers [(exn:fail:filesystem? (lambda (e) #f))]
    (delete-file path)
    #t))

(define (call-with-temporary-file str proc)
  (define filename (make-temporary-file))
  (with-handlers [((lambda (e) #t) (lambda (e) (delete-file* filename)))]
    (display-to-file str filename #:exists 'truncate)
    (proc filename)
    (delete-file* filename)))

;;---------------------------------------------------------------------------

(define (xexpr-trim-whitespace x) ;; hacky
  (match x
    [(cons a d)
     (define a1 (xexpr-trim-whitespace a))
     (define d1 (xexpr-trim-whitespace d))
     (if (equal? a1 "") d1 (cons a1 d1))]
    [(? string? s) (string-trim s)]
    [other other]))

(define (string->xexpr/defaults str)
  (xexpr-trim-whitespace (string->xexpr str)))

;;---------------------------------------------------------------------------

(define (clean-mac str)
  (string-replace (string-replace (string-upcase str) ":" "") "\"" ""))

(define (substitute template vars)
  (match template
    [(regexp #px"^(([^{]|\\{[^{])*)\\{\\{([^}]*)\\}\\}(.*)$" (list _ pre _ in post))
     (string-append pre
                    (hash-ref vars (string->symbol (string-trim in)))
                    (substitute post vars))]
    [_ template]))

(check-equal? (substitute "a {{b}} c {{ b }} d" (hash 'b "b")) "a b c b d")

;;---------------------------------------------------------------------------

(define (run program . args)
  (apply system* (find-executable-path program) (filter values args)))

(define (run/output #:check? [check? #t] program . args)
  (define ok? #f)
  (define output
    (with-output-to-string
      (lambda ()
        (set! ok? (apply run program args)))))
  (and (or (not check?) ok?) output))

(define-syntax-rule (with-silent-stderr expr ...)
  (parameterize ((current-error-port (open-output-nowhere))) expr ...))

;;---------------------------------------------------------------------------

;; Set LIBVIRT_DEFAULT_URI appropriately for the usual case.
(void (putenv "LIBVIRT_DEFAULT_URI"
              (or (getenv "LIBVIRT_DEFAULT_URI")
                  "qemu:///system")))

(define (run-virsh . args) (apply run "virsh" args))
(define (run-virsh/output . args) (apply run/output "virsh" args))

(define (domain-info name/id/uuid #:inactive? [inactive? #f])
  (define xml-str
    (with-silent-stderr
      (run-virsh/output "dumpxml" name/id/uuid (and inactive? "--inactive"))))
  (and xml-str (string->xexpr/defaults xml-str)))

(define (list-domains . flags)
  (filter (lambda (d) (not (equal? d "")))
          (string-split (apply run-virsh/output "list" flags) "\n")))

(define (all-domains) (list-domains "--name" "--all"))
(define (running-domains) (list-domains "--name"))

;;---------------------------------------------------------------------------

(define (image-info image-file-name)
  (define json-str
    (with-silent-stderr
      (run/output "qemu-img" "info"
                  "--force-share"
                  "--output=json"
                  "--backing-chain"
                  image-file-name)))
  (and json-str (string->jsexpr json-str)))
