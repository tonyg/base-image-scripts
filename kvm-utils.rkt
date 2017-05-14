#lang racket

(provide something-exists?
         delete-file*
         call-with-temporary-file

         xexpr-trim-whitespace
         string->xexpr/defaults

         clean-mac
         substitute

         domain-info
         running-domains)

(require xml)
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

;; Set LIBVIRT_DEFAULT_URI appropriately for the usual case.
(void (putenv "LIBVIRT_DEFAULT_URI"
              (or (getenv "LIBVIRT_DEFAULT_URI")
                  "qemu:///system")))

(define (domain-info name/id/uuid)
  (define ok? #f)
  (define xml-str
    (parameterize ((current-error-port (open-output-nowhere)))
      (with-output-to-string
        (lambda ()
          (set! ok? (system* (find-executable-path "virsh") "dumpxml" name/id/uuid))))))
  (and ok? (string->xexpr/defaults xml-str)))

(define (running-domains)
  (filter (lambda (d) (not (equal? d "")))
          (string-split (with-output-to-string
                          (lambda ()
                            (system* (find-executable-path "virsh") "list" "--name")))
                        "\n")))

