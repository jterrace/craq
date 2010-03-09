
# 1 "/home/max/sfslite/1.2/libtame/tame_nlock.Th"


// -*-c++-*-
/* $Id: tame.h 2077 2006-07-07 18:24:23Z max $ */

#ifndef _LIBTAME_NLOCK_H_
#define _LIBTAME_NLOCK_H_

#include "async.h"
#include "list.h"
#include "tame.h"
#include "tame_lock.h"

//
// Named locks.  Kept in a table, indexed by the type T.
//
namespace tame {

  template<class T> class lock_table_t;
  
  template<class T>
  class named_lock_t : public lock_t {
  public:
    named_lock_t (T i, lock_t::mode_t m = lock_t::OPEN) 
      : lock_t (m), _name (i), _refcnt (0) {}
    
    void incref () { _refcnt ++; }
    
    void decref (lock_table_t<T> *t) 
    {
      -- _refcnt ;
      assert (_refcnt >= 0);
      if (_refcnt == 0) {
	assert (_mode == OPEN);
	t->remove (this);
	delete this;
      }
    }
    
    T _name;
    ihash_entry<named_lock_t> _lnk;
  private:
    int _refcnt;
  };
  
  template<class T>
  class lock_handle_t : public virtual refcount {
  public:
    lock_handle_t (lock_table_t<T> *t, named_lock_t<T> *l)
      : _tab (t), _lock (l), _released (false) { l->incref (); }
    
    ~lock_handle_t ()
    {
      if (!_released) release ();
      _lock->decref (_tab);
    }
    
    void cancel () { _released = true; _lock->cancel (_waiter); }
    void release () { _released = true; _lock->release (); }
    void set_waiter (lock_t::waiter_t *w) { _waiter = w; }
    
  private:
    lock_table_t<T> *_tab;
    named_lock_t<T> *_lock;
    lock_t::waiter_t *_waiter;
    bool _released;
  };
  
  template<class T>
  class lock_table_t {
  public:
    lock_table_t () {}
    void remove (named_lock_t<T> *l) { _locks.remove (l); }
    void acquire (ptr<lock_handle_t<T> > *out,
		  T n, lock_t::mode_t mode, cbv cb,
		  CLOSURE);
  private:
    ihash<T, named_lock_t<T>, &named_lock_t<T>::_name, 
	  &named_lock_t<T>::_lnk> _locks;
  };
  
  
  
# 83 "/home/max/sfslite/1.2/libtame/tame_nlock.Th"
template< class T > class lock_table_t_T___acquire__closure_t : public closure_t { public:   lock_table_t_T___acquire__closure_t (lock_table_t< T > *_self,  ptr< lock_handle_t< T > > *out,  T n,  lock_t::mode_t mode,  cbv cb) : closure_t ("/home/max/sfslite/1.2/libtame/tame_nlock.Th", "lock_table_t< T >::acquire"), _self (_self),  _stack (_self, out, n, mode, cb), _args (out, n, mode, cb) {}   typedef void  (lock_table_t< T >::*method_type_t) ( ptr< lock_handle_t< T > > *,  T ,  lock_t::mode_t ,  cbv , ptr<closure_t>);   void set_method_pointer (method_type_t m) { _method = m; }   void reenter ()   {     ((*_self).*_method)  (_args.out, _args.n, _args.mode, _args.cb, mkref (this));   } void v_reenter () { reenter (); }   struct stack_t {     stack_t (lock_table_t< T > *_self,  ptr< lock_handle_t< T > > *out,  T n,  lock_t::mode_t mode,  cbv cb) : l (NULL), w (NULL), do_acquire (true)  {}      named_lock_t< T > *l;      ptr< lock_handle_t< T > > ret;      lock_t::waiter_t *w;      bool do_acquire;   };   struct args_t {     args_t ( ptr< lock_handle_t< T > > *out,  T n,  lock_t::mode_t mode,  cbv cb) : out (out), n (n), mode (mode), cb (cb) {}      ptr< lock_handle_t< T > > *out;      T n;      lock_t::mode_t mode;      cbv cb;   };   lock_table_t< T > *_self;   stack_t _stack;   args_t _args;   method_type_t _method;   bool is_onstack (const void *p) const   {     return (static_cast<const void *> (&_stack) <= p &&             static_cast<const void *> (&_stack + 1) > p);   } }; 
# 83 "/home/max/sfslite/1.2/libtame/tame_nlock.Th"
template< class T >
void 
lock_table_t< T >::acquire( ptr< lock_handle_t< T > > *__tame_out,  T __tame_n,  lock_t::mode_t __tame_mode,  cbv __tame_cb, ptr<closure_t> __cls_g)
{
    
# 87 "/home/max/sfslite/1.2/libtame/tame_nlock.Th"
  lock_table_t_T___acquire__closure_t< T > *__cls;   ptr<lock_table_t_T___acquire__closure_t< T >  > __cls_r;   if (!__cls_g) {     if (tame_check_leaks ()) start_rendezvous_collection ();     __cls_r = New refcounted<lock_table_t_T___acquire__closure_t< T > > (this, __tame_out, __tame_n, __tame_mode, __tame_cb);     if (tame_check_leaks ()) __cls_r->collect_rendezvous ();     __cls = __cls_r;     __cls_g = __cls_r;     __cls->set_method_pointer (&lock_table_t< T >::acquire);   } else {     __cls =     reinterpret_cast<lock_table_t_T___acquire__closure_t< T > *> (static_cast<closure_t *> (__cls_g));     __cls_r = mkref (__cls);   }    named_lock_t< T > *&l = __cls->_stack.l;    ptr< lock_handle_t< T > > &ret = __cls->_stack.ret;    lock_t::waiter_t *&w = __cls->_stack.w;    bool &do_acquire = __cls->_stack.do_acquire;    ptr< lock_handle_t< T > > *&out = __cls->_args.out;    T &n = __cls->_args.n;    lock_t::mode_t &mode = __cls->_args.mode;    cbv &cb = __cls->_args.cb;    use_reference (out);     use_reference (n);     use_reference (mode);     use_reference (cb);    switch (__cls->jumpto ()) {   case 0: break;   case 1:     goto lock_table_t_T___acquire__label_1;     break;   default:     panic ("unexpected case.\n");     break;   }
# 92 "/home/max/sfslite/1.2/libtame/tame_nlock.Th"

    
    l = _locks[n];
    if (!l) {
      l = New named_lock_t<T> (n, mode);
      _locks.insert (l);
      do_acquire = false;
    } 
    ret = New refcounted<lock_handle_t<T> > (this, l);
    *out = ret;
    if (do_acquire) {
      
# 103 "/home/max/sfslite/1.2/libtame/tame_nlock.Th"
  do {     do {       closure_wrapper<lock_table_t_T___acquire__closure_t< T > > __cls_g (__cls_r);     __cls->init_block (1, 103);     __cls->set_jumpto (1); 
# 103 "/home/max/sfslite/1.2/libtame/tame_nlock.Th"
 
	w = l->acquire (mode, mkevent ()); 
	ret->set_waiter (w);
      
# 106 "/home/max/sfslite/1.2/libtame/tame_nlock.Th"
      if (!__cls->block_dec_count (__FL__))       return;     } while (0);  lock_table_t_T___acquire__label_1:       ;   } while (0);
# 106 "/home/max/sfslite/1.2/libtame/tame_nlock.Th"

      ret->set_waiter (NULL);
    } 
    (*cb) ();
  
# 110 "/home/max/sfslite/1.2/libtame/tame_nlock.Th"
  do {   __cls->end_of_scope_checks (110);   return;   } while (0);
# 110 "/home/max/sfslite/1.2/libtame/tame_nlock.Th"
}

};
  
  
#endif /* _LIBTAME_LOCK_H_ */
  
  
