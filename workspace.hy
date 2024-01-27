;; ReplRequestHandler

(setv server1 (ReplServer #("127.0.0.1" 1337) ReplRequestHandler))

;; ~/hy/HyREPL/tests/tests.hy

;; ソケット

(setv s1 (socket.socket :family socket.AF-UNIX))
(.connect s1 sock)
(.sendall s1 (encode {"op" "eval" "code" "(+ 2 2)"}))
(.recv s1 1)

=> => (test-code-eval)
test_code_eval()
in TestServer __init__
in TestServer __enter__
after with
DEBUG: in soc-send message: {'op': 'eval', 'code': '(+ 2 2)'}
DEBUG soc-send: after sendall, message: b'd2:op4:eval4:code7:(+ 2 2)e'
DEBUG soc-send: after setblocking
DEBUG: after exit first try
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
DEBUG: after exit first try
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
DEBUG: after exit first try
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
DEBUG: after exit first try
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
DEBUG: after exit first try
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
DEBUG: after exit first try
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
DEBUG: after exit first try
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
DEBUG: after exit first try
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
DEBUG ReplRequestHandler.handle tmp: b'd2:op4:eval4:code7:(+ 2 2)e'
DEBUG: after exit first try
DEBUG ReplRequestHandler.handle buf: bytearray(b'd2:op4:eval4:code7:(+ 2 2)e')
before decode
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEGUB ReplRequestHandler.handle m: ({'op': 'eval', 'code': '(+ 2 2)'}, bytearray(b''))
DEBUG soc-send: buf: b''
DEBUG self.session: None
DEBUG sessions: {'31530ae9-50aa-4eec-bc4a-579a05a44c70': 31530ae9-50aa-4eec-bc4a-579a05a44c70, 'e29c7f54-12a9-46cd-ab6d-540ee4c9db39': e29c7f54-12a9-46cd-ab6d-540ee4c9db39}
DEBUG: after exit first try
DEBUG ReplRequestHandler.handle: session is None, create new Session
Session.__init__
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG: self.session: c93af177-b129-4e9e-ba4d-d74c363197a6, (get m 0): {'op': 'eval', 'code': '(+ 2 2)'}, self.request: <socket.socket fd=8, family=1, type=1, proto=0, laddr=/tmp/HyREPL-test>
DEBUG soc-send: buf: b''
DEBUG call session.handle: self.session.handle: <bound method Session.handle of c93af177-b129-4e9e-ba4d-d74c363197a6>, (get m 0): {'op': 'eval', 'code': '(+ 2 2)'}, self.request: <socket.socket fd=8, family=1, type=1, proto=0, laddr=/tmp/HyREPL-test>
DEBUG: after exit first try
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
DEBUG: after exit first try
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
DEBUG Session.handle: msg: {'op': 'eval', 'code': '(+ 2 2)'}, transport: <socket.socket fd=8, family=1, type=1, proto=0, laddr=/tmp/HyREPL-test>
eval
DEBUG[defop fn-checked]: before check, {'code': 'The code to be evaluated'}, dict_keys(['code'])
DEBUG: after exit first try
DEBUG[defop fn-checked]: g!r: code
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
DEBUG[defop fn-checked]: after check, g!failed: False
DEBUG[eval]: in body of eval
DEBUG[get-workaround]: rv: None
DEBUG: after exit first try
DEBUG[eval]: w: <function get_workaround.<locals>._hy_anon_var_3 at 0x7f059bd574c0>
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG[get-workaround]: s: c93af177-b129-4e9e-ba4d-d74c363197a6, m: {'op': 'eval', 'code': '(+ 2 2)'}
DEBUG soc-send: buf: b''
DEBUG[eval]: msg: {'op': 'eval', 'code': '(+ 2 2)'}
DEBUG: after exit first try
=== in eval ====================================
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG[eval]: (type session): <class 'HyREPL.session.Session'>
DEBUG soc-send: buf: b''
DEBUG[eval]: (dir session): ['__class__', '__delattr__', '__dict__', '__dir__', '__doc__', '__eq__', '__format__', '__ge__', '__getattribute__', '__getstate__', '__gt__', '__hash__', '__init__', '__init_subclass__', '__le__', '__lt__', '__module__', '__ne__', '__new__', '__reduce__', '__reduce_ex__', '__repr__', '__setattr__', '__sizeof__', '__str__', '__subclasshook__', '__weakref__', 'eval_id', 'handle', 'last_traceback', 'lastmsg', 'lock', 'repl', 'status', 'uuid', 'write']
DEBUG: after exit first try
DEBUG[eval]: session.repl: <InterruptibleEval(Thread-7, initial)>
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
...
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
DEBUG: out: {'status': ['eval-error'], 'ex': 'TypeError', 'root-ex': 'TypeError', 'id': None, 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}
DEBUG: after exit first try
=== in session.write ==========================
DEBUG soc-send: e: invalid literal for int() with base 10: ''
b'd6:statusl10:eval-errore2:ex9:TypeError7:root-ex9:TypeError2:id0:7:session36:c93af177-b129-4e9e-ba4d-d74c363197a6e'
DEBUG soc-send: buf: b''
DEBUG: out: {'err': "'module' object is not callable", 'id': None, 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}
=== in session.write ==========================
b"d3:err31:'module' object is not callable2:id0:7:session36:c93af177-b129-4e9e-ba4d-d74c363197a6e"
DEBUG: out: {'status': ['eval-error'], 'ex': 'TypeError', 'root-ex': 'TypeError', 'id': None, 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}
DEBUG: after exit first try
=== in session.write ==========================
DEBUG soc-send: resp: {'status': ['eval-error'], 'ex': 'TypeError', 'root-ex': 'TypeError', 'id': '', 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}, rest: b''
b'd6:statusl10:eval-errore2:ex9:TypeError7:root-ex9:TypeError2:id0:7:session36:c93af177-b129-4e9e-ba4d-d74c363197a6e'
DEBUG: after exit first try
DEBUG soc-send: resp: {'err': "'module' object is not callable", 'id': '', 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}, rest: b''
DEBUG: after exit first try
DEBUG soc-send: resp: {'status': ['eval-error'], 'ex': 'TypeError', 'root-ex': 'TypeError', 'id': '', 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}, rest: b''
DEBUG: after exit first try
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
DEBUG: after exit first try
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
DEBUG: after exit first try
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
DEBUG: after exit first try
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
DEBUG: after exit first try
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
DEBUG: after exit first try
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
DEBUG: after exit first try
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
DEBUG: after exit first try
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
DEBUG: after exit first try
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG soc-send: buf: b''
DEBUG: after exit first try
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG: out: {'err': "'module' object is not callable", 'id': None, 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}
DEBUG soc-send: buf: b''
=== in session.write ==========================
b"d3:err31:'module' object is not callable2:id0:7:session36:c93af177-b129-4e9e-ba4d-d74c363197a6e"
DEBUG: out: {'status': ['eval-error'], 'ex': 'TypeError', 'root-ex': 'TypeError', 'id': None, 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}
=== in session.write ==========================
DEBUG: after exit first try
b'd6:statusl10:eval-errore2:ex9:TypeError7:root-ex9:TypeError2:id0:7:session36:c93af177-b129-4e9e-ba4d-d74c363197a6e'
DEBUG soc-send: e: invalid literal for int() with base 10: ''
DEBUG: out: {'err': "'module' object is not callable", 'id': None, 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}
DEBUG soc-send: buf: b''
=== in session.write ==========================
b"d3:err31:'module' object is not callable2:id0:7:session36:c93af177-b129-4e9e-ba4d-d74c363197a6e"
DEBUG: out: {'status': ['done'], 'id': None, 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}
=== in session.write ==========================
b'd6:statusl4:donee2:id0:7:session36:c93af177-b129-4e9e-ba4d-d74c363197a6e'
DEBUG: after exit first try
DEBUG soc-send: resp: {'err': "'module' object is not callable", 'id': '', 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}, rest: b'd6:statusl10:eval-errore2:ex9:TypeError7:root-ex9:TypeError2:id0:7:session36:c93af177-b129-4e9e-ba4d-d74c363197a6e'
DEBUG: after exit first try
DEBUG soc-send: resp: {'status': ['eval-error'], 'ex': 'TypeError', 'root-ex': 'TypeError', 'id': '', 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}, rest: b"d3:err31:'module' object is not callable2:id0:7:session36:c93af177-b129-4e9e-ba4d-d74c363197a6ed6:statusl4:donee2:id0:7:session36:c93af177-b129-4e9e-ba4d-d74c363197a6e"
DEBUG: after exit first try
DEBUG soc-send: resp: {'err': "'module' object is not callable", 'id': '', 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}, rest: b'd6:statusl4:donee2:id0:7:session36:c93af177-b129-4e9e-ba4d-d74c363197a6e'
DEBUG: after exit first try
DEBUG soc-send: resp: {'status': ['done'], 'id': '', 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}, rest: b''
code: {'op': 'eval', 'code': '(+ 2 2)'}, ret: [{'status': ['eval-error'], 'ex': 'TypeError', 'root-ex': 'TypeError', 'id': '', 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}, {'err': "'module' object is not callable", 'id': '', 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}, {'status': ['eval-error'], 'ex': 'TypeError', 'root-ex': 'TypeError', 'id': '', 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}, {'err': "'module' object is not callable", 'id': '', 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}, {'status': ['eval-error'], 'ex': 'TypeError', 'root-ex': 'TypeError', 'id': '', 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}, {'err': "'module' object is not callable", 'id': '', 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}, {'status': ['done'], 'id': '', 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}], value: {'status': ['eval-error'], 'ex': 'TypeError', 'root-ex': 'TypeError', 'id': '', 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}, status: {'err': "'module' object is not callable", 'id': '', 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}
DEBUG ReplRequestHandler.handle tmp: b''
=> DEBUG: out: {'status': ['need-input'], 'id': None, 'session': 'c93af177-b129-4e9e-ba4d-d74c363197a6'}
=== in session.write ==========================
b'd6:statusl10:need-inpute2:id0:7:session36:c93af177-b129-4e9e-ba4d-d74c363197a6e'
Client gone: [Errno 9] Bad file descriptor


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; TODO: クライアント側のdebug printを抑制

=> => (test-code-eval)
test_code_eval()
in TestServer __init__
in TestServer __enter__
after with
DEBUG ReplRequestHandler.handle tmp: b'd2:op4:eval4:code7:(+ 2 2)e'
DEBUG ReplRequestHandler.handle buf: bytearray(b'd2:op4:eval4:code7:(+ 2 2)e')
before decode
DEGUB ReplRequestHandler.handle m: ({'op': 'eval', 'code': '(+ 2 2)'}, bytearray(b''))
DEBUG self.session: None
DEBUG sessions: {}
DEBUG ReplRequestHandler.handle: session is None, create new Session
Session.__init__
DEBUG: self.session: 586e9ff1-1e86-4a4b-9f10-49c0e11b63bb, (get m 0): {'op': 'eval', 'code': '(+ 2 2)'}, self.request: <socket.socket fd=5, family=1, type=1, proto=0, laddr=/tmp/HyREPL-test>
DEBUG call session.handle: self.session.handle: <bound method Session.handle of 586e9ff1-1e86-4a4b-9f10-49c0e11b63bb>, (get m 0): {'op': 'eval', 'code': '(+ 2 2)'}, self.request: <socket.socket fd=5, family=1, type=1, proto=0, laddr=/tmp/HyREPL-test>
DEBUG[Session.handle]: msg: {'op': 'eval', 'code': '(+ 2 2)'}, transport: <socket.socket fd=5, family=1, type=1, proto=0, laddr=/tmp/HyREPL-test>
eval
DEBUG[defop fn-checked]: before check, {'code': 'The code to be evaluated'}, dict_keys(['code'])
DEBUG[defop fn-checked]: g!r: code
DEBUG[defop fn-checked]: after check, g!failed: False
DEBUG[eval]: in body of eval
DEBUG[get-workaround]: rv: None
DEBUG[eval]: w: <function get_workaround.<locals>._hy_anon_var_3 at 0x7fd50f481620>
DEBUG[get-workaround]: s: 586e9ff1-1e86-4a4b-9f10-49c0e11b63bb, m: {'op': 'eval', 'code': '(+ 2 2)'}
DEBUG[eval]: msg: {'op': 'eval', 'code': '(+ 2 2)'}
=== in eval ====================================
DEBUG[eval]: (type session): <class 'HyREPL.session.Session'>
DEBUG[eval]: (dir session): ['__class__', '__delattr__', '__dict__', '__dir__', '__doc__', '__eq__', '__format__', '__ge__', '__getattribute__', '__getstate__', '__gt__', '__hash__', '__init__', '__init_subclass__', '__le__', '__lt__', '__module__', '__ne__', '__new__', '__reduce__', '__reduce_ex__', '__repr__', '__setattr__', '__sizeof__', '__str__', '__subclasshook__', '__weakref__', 'eval_id', 'handle', 'last_traceback', 'lastmsg', 'lock', 'repl', 'status', 'uuid', 'write']
DEBUG[eval]: session.repl: <InterruptibleEval(Thread-3, initial)>
;; InterruptibleEvalのスレッドはできてる

DEBUG[Session.write]: out: {'status': ['eval-error'], 'ex': 'TypeError', 'root-ex': 'TypeError', 'id': None, 'session': '586e9ff1-1e86-4a4b-9f10-49c0e11b63bb'}
=== in session.write ==========================
b'd6:statusl10:eval-errore2:ex9:TypeError7:root-ex9:TypeError2:id0:7:session36:586e9ff1-1e86-4a4b-9f10-49c0e11b63bbe'
DEBUG[Session.write]: out: {'err': "'module' object is not callable", 'id': None, 'session': '586e9ff1-1e86-4a4b-9f10-49c0e11b63bb'}
=== in session.write ==========================
b"d3:err31:'module' object is not callable2:id0:7:session36:586e9ff1-1e86-4a4b-9f10-49c0e11b63bbe"
DEBUG[Session.write]: out: {'status': ['eval-error'], 'ex': 'TypeError', 'root-ex': 'TypeError', 'id': None, 'session': '586e9ff1-1e86-4a4b-9f10-49c0e11b63bb'}
=== in session.write ==========================
b'd6:statusl10:eval-errore2:ex9:TypeError7:root-ex9:TypeError2:id0:7:session36:586e9ff1-1e86-4a4b-9f10-49c0e11b63bbe'
DEBUG[Session.write]: out: {'err': "'module' object is not callable", 'id': None, 'session': '586e9ff1-1e86-4a4b-9f10-49c0e11b63bb'}
=== in session.write ==========================
b"d3:err31:'module' object is not callable2:id0:7:session36:586e9ff1-1e86-4a4b-9f10-49c0e11b63bbe"
DEBUG[Session.write]: out: {'status': ['eval-error'], 'ex': 'TypeError', 'root-ex': 'TypeError', 'id': None, 'session': '586e9ff1-1e86-4a4b-9f10-49c0e11b63bb'}
=== in session.write ==========================
b'd6:statusl10:eval-errore2:ex9:TypeError7:root-ex9:TypeError2:id0:7:session36:586e9ff1-1e86-4a4b-9f10-49c0e11b63bbe'
DEBUG[Session.write]: out: {'err': "'module' object is not callable", 'id': None, 'session': '586e9ff1-1e86-4a4b-9f10-49c0e11b63bb'}
=== in session.write ==========================
b"d3:err31:'module' object is not callable2:id0:7:session36:586e9ff1-1e86-4a4b-9f10-49c0e11b63bbe"
DEBUG[Session.write]: out: {'status': ['done'], 'id': None, 'session': '586e9ff1-1e86-4a4b-9f10-49c0e11b63bb'}
=== in session.write ==========================
b'd6:statusl4:donee2:id0:7:session36:586e9ff1-1e86-4a4b-9f10-49c0e11b63bbe'
code: {'op': 'eval', 'code': '(+ 2 2)'}, ret: [{'status': ['eval-error'], 'ex': 'TypeError', 'root-ex': 'TypeError', 'id': '', 'session': '586e9ff1-1e86-4a4b-9f10-49c0e11b63bb'}, {'err': "'module' object is not callable", 'id': '', 'session': '586e9ff1-1e86-4a4b-9f10-49c0e11b63bb'}, {'status': ['eval-error'], 'ex': 'TypeError', 'root-ex': 'TypeError', 'id': '', 'session': '586e9ff1-1e86-4a4b-9f10-49c0e11b63bb'}, {'err': "'module' object is not callable", 'id': '', 'session': '586e9ff1-1e86-4a4b-9f10-49c0e11b63bb'}, {'status': ['eval-error'], 'ex': 'TypeError', 'root-ex': 'TypeError', 'id': '', 'session': '586e9ff1-1e86-4a4b-9f10-49c0e11b63bb'}, {'err': "'module' object is not callable", 'id': '', 'session': '586e9ff1-1e86-4a4b-9f10-49c0e11b63bb'}, {'status': ['done'], 'id': '', 'session': '586e9ff1-1e86-4a4b-9f10-49c0e11b63bb'}], value: {'status': ['eval-error'], 'ex': 'TypeError', 'root-ex': 'TypeError', 'id': '', 'session': '586e9ff1-1e86-4a4b-9f10-49c0e11b63bb'}, status: {'err': "'module' object is not callable", 'id': '', 'session': '586e9ff1-1e86-4a4b-9f10-49c0e11b63bb'}
DEBUG ReplRequestHandler.handle tmp: b''
=> DEBUG[Session.write]: out: {'status': ['need-input'], 'id': None, 'session': '586e9ff1-1e86-4a4b-9f10-49c0e11b63bb'}
=== in session.write ==========================
b'd6:statusl10:need-inpute2:id0:7:session36:586e9ff1-1e86-4a4b-9f10-49c0e11b63bbe'
Client gone: [Errno 9] Bad file descriptor


;;; InterruptibleEval を単体テストしたい

(import HyREPL.session [Session])
(import HyREPL.ops.eval [InterruptibleEval])

(setv sess1 (Session))
(setv msg1 {"op" "eval" "code" "(+ 2 2)"})

(setv inteval1
      (InterruptibleEval msg1 sess1 print))

(.start inteval1)
