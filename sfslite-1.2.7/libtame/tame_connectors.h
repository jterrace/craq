
# 1 "/home/max/sfslite/1.2/libtame/tame_connectors.Th"

// -*-c++-*-
/* $Id: tame.h 2077 2006-07-07 18:24:23Z max $ */

#ifndef _LIBTAME_CONNECTORS_H_
#define _LIBTAME_CONNECTORS_H_

#include "tame.h"

//
// Connectors that combine different events in useful ways.
//

typedef enum { OUTCOME_SUCC = 0,
	       OUTCOME_TIMEDOUT = 1,
	       OUTCOME_CANCELLED = 2,
	       OUTCOME_SIGNALED = 3,
	       OUTCOME_DISCARDED = 4 } outcome_t;

inline bool valid_timeout (int s, int ns)
{
  return (s >= 0 && ns >= 0 && (s > 0 || ns > 0));
}

template<class T1=void, class T2=void, class T3=void>
class connector_t {
public:

  connector_t () {}

  static typename event<T1,T2,T3>::ptr
  cnc (typename event<T1,T2,T3>::ref in, 
       _event_cancel_base *cobj,
       int to_s,
       int to_ns,
       outcome_t *ocp = NULL)
  {
    typename event<T1,T2,T3>::ptr  ncb;
    connector_t<T1,T2,T3> c;
    c.__cnc (&ncb, in, cobj, to_s, to_ns, ocp);
    return ncb;
  }

  static typename event<T1,T2,T3>::ptr
  sig (typename event<T1,T2,T3>::ref in, 
       vec<int> sigv,
       int *res,
       _event_cancel_base *cobj)
  {
    typename event<T1,T2,T3>::ptr  ncb;
    connector_t<T1,T2,T3> c;
    c.__sig (&ncb, in, sigv, res, cobj);
    return ncb;
  }

  static typename event<T1,T2,T3>::ptr
  first (typename event<T1,T2,T3>::ref *es, size_t sz)
  {
    typename event<T1,T2,T3>::ptr ncb;
    connector_t<T1,T2,T3> c;
    c.__first (es, sz);
    return ncb;
  }

private:
  void __cnc (typename event<T1,T2,T3>::ptr *out, 
	      typename event<T1,T2,T3>::ref in, 
	      _event_cancel_base *c, 
	      int to_s, 
	      int to_ns,
	      outcome_t *ocp,
	      CLOSURE);

  void __sig (typename event<T1,T2,T3>::ptr *out, 
	      typename event<T1,T2,T3>::ref in, 
	      vec<int> sigs,
	      int *sigp,
	      _event_cancel_base *cobj, 
	      CLOSURE);

};

# 83 "/home/max/sfslite/1.2/libtame/tame_connectors.Th"
template< class T1, class T2, class T3 > class connector_t_T1_T2_T3_____sig__closure_t : public closure_t { public:   connector_t_T1_T2_T3_____sig__closure_t (connector_t< T1  ,  T2  ,  T3 > *_self,  typename event< T1  ,  T2  ,  T3 >::ptr *out,  typename event< T1  ,  T2  ,  T3 >::ref in,  vec< int > sigs,  int *sigp,  _event_cancel_base *cobj) : closure_t ("/home/max/sfslite/1.2/libtame/tame_connectors.Th", "connector_t< T1  ,  T2  ,  T3 >::__sig"), _self (_self),  _stack (_self, out, in, sigs, sigp, cobj), _args (out, in, sigs, sigp, cobj) {}   typedef void  (connector_t< T1  ,  T2  ,  T3 >::*method_type_t) ( typename event< T1  ,  T2  ,  T3 >::ptr *,  typename event< T1  ,  T2  ,  T3 >::ref ,  vec< int > ,  int *,  _event_cancel_base *, ptr<closure_t>);   void set_method_pointer (method_type_t m) { _method = m; }   void reenter ()   {     ((*_self).*_method)  (_args.out, _args.in, _args.sigs, _args.sigp, _args.cobj, mkref (this));   } void v_reenter () { reenter (); }   struct stack_t {     stack_t (connector_t< T1  ,  T2  ,  T3 > *_self,  typename event< T1  ,  T2  ,  T3 >::ptr *out,  typename event< T1  ,  T2  ,  T3 >::ref in,  vec< int > sigs,  int *sigp,  _event_cancel_base *cobj) : rv ("/home/max/sfslite/1.2/libtame/tame_connectors.Th", 91)  {}      rendezvous_t< int > rv;      int i;      int sig;   };   struct args_t {     args_t ( typename event< T1  ,  T2  ,  T3 >::ptr *out,  typename event< T1  ,  T2  ,  T3 >::ref in,  vec< int > sigs,  int *sigp,  _event_cancel_base *cobj) : out (out), in (in), sigs (sigs), sigp (sigp), cobj (cobj) {}      typename event< T1  ,  T2  ,  T3 >::ptr *out;      typename event< T1  ,  T2  ,  T3 >::ref in;      vec< int > sigs;      int *sigp;      _event_cancel_base *cobj;   };   connector_t< T1  ,  T2  ,  T3 > *_self;   stack_t _stack;   args_t _args;   method_type_t _method;   bool is_onstack (const void *p) const   {     return (static_cast<const void *> (&_stack) <= p &&             static_cast<const void *> (&_stack + 1) > p);   } }; 
# 83 "/home/max/sfslite/1.2/libtame/tame_connectors.Th"
template< class T1, class T2, class T3 >
void 
connector_t< T1  ,  T2  ,  T3 >::__sig( typename event< T1  ,  T2  ,  T3 >::ptr *__tame_out,  typename event< T1  ,  T2  ,  T3 >::ref __tame_in,  vec< int > __tame_sigs,  int *__tame_sigp,  _event_cancel_base *__tame_cobj, ptr<closure_t> __cls_g)
{
# 89 "/home/max/sfslite/1.2/libtame/tame_connectors.Th"

  
# 90 "/home/max/sfslite/1.2/libtame/tame_connectors.Th"
  connector_t_T1_T2_T3_____sig__closure_t< T1  ,  T2  ,  T3 > *__cls;   ptr<connector_t_T1_T2_T3_____sig__closure_t< T1  ,  T2  ,  T3 >  > __cls_r;   if (!__cls_g) {     if (tame_check_leaks ()) start_rendezvous_collection ();     __cls_r = New refcounted<connector_t_T1_T2_T3_____sig__closure_t< T1  ,  T2  ,  T3 > > (this, __tame_out, __tame_in, __tame_sigs, __tame_sigp, __tame_cobj);     if (tame_check_leaks ()) __cls_r->collect_rendezvous ();     __cls = __cls_r;     __cls_g = __cls_r;     __cls->set_method_pointer (&connector_t< T1  ,  T2  ,  T3 >::__sig);   } else {     __cls =     reinterpret_cast<connector_t_T1_T2_T3_____sig__closure_t< T1  ,  T2  ,  T3 > *> (static_cast<closure_t *> (__cls_g));     __cls_r = mkref (__cls);   }    rendezvous_t< int > &rv = __cls->_stack.rv;    int &i = __cls->_stack.i;    int &sig = __cls->_stack.sig;    typename event< T1  ,  T2  ,  T3 >::ptr *&out = __cls->_args.out;    typename event< T1  ,  T2  ,  T3 >::ref &in = __cls->_args.in;    vec< int > &sigs = __cls->_args.sigs;    int *&sigp = __cls->_args.sigp;    _event_cancel_base *&cobj = __cls->_args.cobj;    use_reference (out);     use_reference (in);     use_reference (sigs);     use_reference (sigp);     use_reference (cobj);    switch (__cls->jumpto ()) {   case 0: break;   case 1:     goto connector_t_T1_T2_T3_____sig__label_1;     break;   default:     panic ("unexpected case.\n");     break;   }
# 94 "/home/max/sfslite/1.2/libtame/tame_connectors.Th"


  if (cobj) {
    cobj->set_cancel_notifier (mkevent (rv, -1));
  }
  for (i = 0; i < sigs.size (); i++) {
    sigcb (sigs[i], mkevent (rv, sigs[i]));
  }
  *out = mkevent_rs (in->slot_set (), rv, 0);
  (*out)->set_cancel_notifier (mkevent (rv, -2));

  
# 105 "/home/max/sfslite/1.2/libtame/tame_connectors.Th"
connector_t_T1_T2_T3_____sig__label_1: do {   if (!(rv)._ti_next_trigger (sig)) {     __cls->set_jumpto (1);       (rv)._ti_set_join_cls (__cls_r);       return;   } else {     (rv)._ti_clear_join_method ();   } } while (0);
# 105 "/home/max/sfslite/1.2/libtame/tame_connectors.Th"


  for (i = 0; i < sigs.size (); i++) {
    sigcb (sigs[i], NULL);
  }

  rv.cancel ();
  if (sigp) *sigp = sig;

  in->trigger_no_assign ();
# 115 "/home/max/sfslite/1.2/libtame/tame_connectors.Th"
  do {   __cls->end_of_scope_checks (115);   return;   } while (0);
# 115 "/home/max/sfslite/1.2/libtame/tame_connectors.Th"
}


# 118 "/home/max/sfslite/1.2/libtame/tame_connectors.Th"
template< class T1, class T2, class T3 > class connector_t_T1_T2_T3_____cnc__closure_t : public closure_t { public:   connector_t_T1_T2_T3_____cnc__closure_t (connector_t< T1  ,  T2  ,  T3 > *_self,  typename event< T1  ,  T2  ,  T3 >::ptr *out,  typename event< T1  ,  T2  ,  T3 >::ref in,  _event_cancel_base *cobj,  int to_s,  int to_ns,  outcome_t *ocp) : closure_t ("/home/max/sfslite/1.2/libtame/tame_connectors.Th", "connector_t< T1  ,  T2  ,  T3 >::__cnc"), _self (_self),  _stack (_self, out, in, cobj, to_s, to_ns, ocp), _args (out, in, cobj, to_s, to_ns, ocp) {}   typedef void  (connector_t< T1  ,  T2  ,  T3 >::*method_type_t) ( typename event< T1  ,  T2  ,  T3 >::ptr *,  typename event< T1  ,  T2  ,  T3 >::ref ,  _event_cancel_base *,  int ,  int ,  outcome_t *, ptr<closure_t>);   void set_method_pointer (method_type_t m) { _method = m; }   void reenter ()   {     ((*_self).*_method)  (_args.out, _args.in, _args.cobj, _args.to_s, _args.to_ns, _args.ocp, mkref (this));   } void v_reenter () { reenter (); }   struct stack_t {     stack_t (connector_t< T1  ,  T2  ,  T3 > *_self,  typename event< T1  ,  T2  ,  T3 >::ptr *out,  typename event< T1  ,  T2  ,  T3 >::ref in,  _event_cancel_base *cobj,  int to_s,  int to_ns,  outcome_t *ocp) : rv ("/home/max/sfslite/1.2/libtame/tame_connectors.Th", 127), tcb (NULL)  {}      rendezvous_t< outcome_t > rv;      outcome_t outc;      timecb_t *tcb;   };   struct args_t {     args_t ( typename event< T1  ,  T2  ,  T3 >::ptr *out,  typename event< T1  ,  T2  ,  T3 >::ref in,  _event_cancel_base *cobj,  int to_s,  int to_ns,  outcome_t *ocp) : out (out), in (in), cobj (cobj), to_s (to_s), to_ns (to_ns), ocp (ocp) {}      typename event< T1  ,  T2  ,  T3 >::ptr *out;      typename event< T1  ,  T2  ,  T3 >::ref in;      _event_cancel_base *cobj;      int to_s;      int to_ns;      outcome_t *ocp;   };   connector_t< T1  ,  T2  ,  T3 > *_self;   stack_t _stack;   args_t _args;   method_type_t _method;   bool is_onstack (const void *p) const   {     return (static_cast<const void *> (&_stack) <= p &&             static_cast<const void *> (&_stack + 1) > p);   } }; 
# 118 "/home/max/sfslite/1.2/libtame/tame_connectors.Th"
template< class T1, class T2, class T3 >
void 
connector_t< T1  ,  T2  ,  T3 >::__cnc( typename event< T1  ,  T2  ,  T3 >::ptr *__tame_out,  typename event< T1  ,  T2  ,  T3 >::ref __tame_in,  _event_cancel_base *__tame_cobj,  int __tame_to_s,  int __tame_to_ns,  outcome_t *__tame_ocp, ptr<closure_t> __cls_g)
{
# 125 "/home/max/sfslite/1.2/libtame/tame_connectors.Th"

  
# 126 "/home/max/sfslite/1.2/libtame/tame_connectors.Th"
  connector_t_T1_T2_T3_____cnc__closure_t< T1  ,  T2  ,  T3 > *__cls;   ptr<connector_t_T1_T2_T3_____cnc__closure_t< T1  ,  T2  ,  T3 >  > __cls_r;   if (!__cls_g) {     if (tame_check_leaks ()) start_rendezvous_collection ();     __cls_r = New refcounted<connector_t_T1_T2_T3_____cnc__closure_t< T1  ,  T2  ,  T3 > > (this, __tame_out, __tame_in, __tame_cobj, __tame_to_s, __tame_to_ns, __tame_ocp);     if (tame_check_leaks ()) __cls_r->collect_rendezvous ();     __cls = __cls_r;     __cls_g = __cls_r;     __cls->set_method_pointer (&connector_t< T1  ,  T2  ,  T3 >::__cnc);   } else {     __cls =     reinterpret_cast<connector_t_T1_T2_T3_____cnc__closure_t< T1  ,  T2  ,  T3 > *> (static_cast<closure_t *> (__cls_g));     __cls_r = mkref (__cls);   }    rendezvous_t< outcome_t > &rv = __cls->_stack.rv;    outcome_t &outc = __cls->_stack.outc;    timecb_t *&tcb = __cls->_stack.tcb;    typename event< T1  ,  T2  ,  T3 >::ptr *&out = __cls->_args.out;    typename event< T1  ,  T2  ,  T3 >::ref &in = __cls->_args.in;    _event_cancel_base *&cobj = __cls->_args.cobj;    int &to_s = __cls->_args.to_s;    int &to_ns = __cls->_args.to_ns;    outcome_t *&ocp = __cls->_args.ocp;    use_reference (out);     use_reference (in);     use_reference (cobj);     use_reference (to_s);     use_reference (to_ns);     use_reference (ocp);    switch (__cls->jumpto ()) {   case 0: break;   case 1:     goto connector_t_T1_T2_T3_____cnc__label_1;     break;   default:     panic ("unexpected case.\n");     break;   }
# 130 "/home/max/sfslite/1.2/libtame/tame_connectors.Th"


  if (cobj) {
    cobj->set_cancel_notifier (mkevent (rv, OUTCOME_CANCELLED)); 
  }

  if (valid_timeout (to_s, to_ns)) {
    tcb = delaycb (to_s, to_ns, mkevent (rv, OUTCOME_TIMEDOUT));
  }

  *out = mkevent_rs (in->slot_set (), rv, OUTCOME_SUCC);
  (*out)->set_cancel_notifier (mkevent (rv, OUTCOME_DISCARDED));
  
# 142 "/home/max/sfslite/1.2/libtame/tame_connectors.Th"
connector_t_T1_T2_T3_____cnc__label_1: do {   if (!(rv)._ti_next_trigger (outc)) {     __cls->set_jumpto (1);       (rv)._ti_set_join_cls (__cls_r);       return;   } else {     (rv)._ti_clear_join_method ();   } } while (0);
# 142 "/home/max/sfslite/1.2/libtame/tame_connectors.Th"


  if (outc != OUTCOME_TIMEDOUT && tcb) {
    timecb_remove (tcb);
  }
  tcb = NULL;

  // Cancel before issuing the trigger, for safety's sake.
  rv.cancel ();

  if (ocp) *ocp = outc;

  in->trigger_no_assign ();
# 155 "/home/max/sfslite/1.2/libtame/tame_connectors.Th"
  do {   __cls->end_of_scope_checks (155);   return;   } while (0);
# 155 "/home/max/sfslite/1.2/libtame/tame_connectors.Th"
}

namespace connector {

  template<typename T1, typename T2, typename T3>
  ref<_event<T1,T2,T3> >
  cnc (ref<_event<T1,T2,T3> > in, _event_cancel_base *cobj, 
	outcome_t *ocp = NULL)
  {
    return connector_t<T1,T2,T3>::cnc (in, cobj, -1, -1, ocp);
  }

  template<typename T1, typename T2, typename T3>
  ref<_event<T1,T2,T3> >
  cnc (ref<_event<T1,T2,T3> > in, _event_cancel_base *cobj, 
       int to_s, int to_ns,
	outcome_t *ocp = NULL)
  {
    return connector_t<T1,T2,T3>::cnc (in, cobj, to_s, to_ns, ocp);
  }

  template<typename T1, typename T2, typename T3>
  ref<_event<T1,T2,T3> >
  timeout (ref<_event<T1,T2,T3> > in, int to_s, int to_ns = 0, 
	   outcome_t *ocp = NULL)
  {
    return connector_t<T1,T2,T3>::cnc (in, NULL, to_s, to_ns, ocp);
  }

  template<typename T1, typename T2, typename T3>
  ref<_event<T1,T2,T3> >
  sig (ref<_event<T1,T2,T3> > in, vec<int> sigs, int *sigp = NULL,
       _event_cancel_base *cobj = NULL)
  {
    return connector_t<T1,T2,T3>::sig (in, sigs, sigp, cobj);
  }

  template<typename T1, typename T2, typename T3>
  ref<_event<T1,T2,T3> >
  first (ref<_event<T1,T2,T3> > *es, size_t sz)
  {
    return connector_t<T1,T2,T3>::first (es, sz);
  }

};

#endif /* _LIBTAME_CONNECTORS_H_ */
