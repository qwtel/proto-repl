(ns proto-repl)

;; Prevent this namespace from being unloaded
(try
  (require 'clojure.tools.namespace.repl)
  (clojure.tools.namespace.repl/disable-reload!)
  (clojure.tools.namespace.repl/disable-unload!)
  (catch Exception _))

(def cmd-queue
  (java.util.concurrent.ArrayBlockingQueue. 10))

(defn print-prompt
  []
  (print "user=> ")
  (flush))

(defn execute-code
  [ns-to-use code]
  (binding [*ns* (or (find-ns ns-to-use) (find-ns 'user))]
    (eval (read-string code))))

(defn execute-commands-on-queue
  []
  (loop [{:keys [ns-to-use code]} (.take cmd-queue)]
    (try
      (println)
      (println (execute-code ns-to-use code))
      (print-prompt)
      (catch Throwable t
        (.printStackTrace t)))
    (recur (.take cmd-queue))))

(defn start-execution-thread
  []
  (def execution-thread
    (Thread. execute-commands-on-queue))
  (.start execution-thread))

(defn stop-execution-thread
  []
  (.stop execution-thread))

(defn enqueue-execution
  [obj]
  (when-not
    (.offer cmd-queue
            ^Object obj
            10
            java.util.concurrent.TimeUnit/SECONDS)
    (println "Timeout putting command on execution queue")))

(start-execution-thread)

; TODO remove this
(println "Proto REPL helper code loaded")

(defn read-eval-print
  []
  (print-prompt)
  (loop [obj (read)]
    (when-not (= :exit obj)
      (enqueue-execution obj)
      (recur (read))))
  (System/exit 0))

(read-eval-print)
