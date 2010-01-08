// -*-c++-*-
/* This file was automatically generated by rpcc. */

#include "donar_rpc.h"

#ifdef MAINTAINER

const strbuf &
rpc_print (const strbuf &sb, const attr_type &obj, int recdepth,
           const char *name, const char *prefix)
{
  const char *p;
  switch (obj) {
  case DONAR_TTL:
    p = "DONAR_TTL";
    break;
  case LATITUDE:
    p = "LATITUDE";
    break;
  case LONGITUDE:
    p = "LONGITUDE";
    break;
  default:
    p = NULL;
    break;
  }
  if (name) {
    if (prefix)
      sb << prefix;
    sb << "attr_type " << name << " = ";
  };
  if (p)
    sb << p;
  else
    sb << int (obj);
  if (prefix)
    sb << ";\n";
  return sb;
};
void
print_attr_type (const void *_objp, const strbuf *_sbp, int _recdepth,
                 const char *_name, const char *_prefix)
{
  rpc_print (_sbp ? *_sbp : warnx, *static_cast<const attr_type *> (_objp),
             _recdepth, _name, _prefix);
}
void
dump_attr_type (const attr_type *objp)
{
  rpc_print (warnx, *objp);
}

const strbuf &
rpc_print (const strbuf &sb, const record_attr &obj, int recdepth,
           const char *name, const char *prefix)
{
  if (name) {
    if (prefix)
      sb << prefix;
    sb << "record_attr " << name << " = ";
  };
  const char *sep;
  str npref;
  if (prefix) {
    npref = strbuf ("%s  ", prefix);
    sep = "";
    sb << "{\n";
  }
  else {
    sep = ", ";
    sb << "{ ";
  }
  rpc_print (sb, obj.type, recdepth, "type", npref);
  sb << sep;
  rpc_print (sb, obj.data, recdepth, "data", npref);
  if (prefix)
    sb << prefix << "};\n";
  else
    sb << " }";
  return sb;
}
void
print_record_attr (const void *_objp, const strbuf *_sbp, int _recdepth,
                   const char *_name, const char *_prefix)
{
  rpc_print (_sbp ? *_sbp : warnx, *static_cast<const record_attr *> (_objp),
             _recdepth, _name, _prefix);
}
void
dump_record_attr (const record_attr *objp)
{
  rpc_print (warnx, *objp);
}

const strbuf &
rpc_print (const strbuf &sb, const record &obj, int recdepth,
           const char *name, const char *prefix)
{
  if (name) {
    if (prefix)
      sb << prefix;
    sb << "record " << name << " = ";
  };
  const char *sep;
  str npref;
  if (prefix) {
    npref = strbuf ("%s  ", prefix);
    sep = "";
    sb << "{\n";
  }
  else {
    sep = ", ";
    sb << "{ ";
  }
  rpc_print (sb, obj.type, recdepth, "type", npref);
  sb << sep;
  rpc_print (sb, obj.content, recdepth, "content", npref);
  sb << sep;
  rpc_print (sb, obj.ttl, recdepth, "ttl", npref);
  sb << sep;
  rpc_print (sb, obj.attrs, recdepth, "attrs", npref);
  if (prefix)
    sb << prefix << "};\n";
  else
    sb << " }";
  return sb;
}
void
print_record (const void *_objp, const strbuf *_sbp, int _recdepth,
              const char *_name, const char *_prefix)
{
  rpc_print (_sbp ? *_sbp : warnx, *static_cast<const record *> (_objp),
             _recdepth, _name, _prefix);
}
void
dump_record (const record *objp)
{
  rpc_print (warnx, *objp);
}

const strbuf &
rpc_print (const strbuf &sb, const subdomain &obj, int recdepth,
           const char *name, const char *prefix)
{
  if (name) {
    if (prefix)
      sb << prefix;
    sb << "subdomain " << name << " = ";
  };
  const char *sep;
  str npref;
  if (prefix) {
    npref = strbuf ("%s  ", prefix);
    sep = "";
    sb << "{\n";
  }
  else {
    sep = ", ";
    sb << "{ ";
  }
  rpc_print (sb, obj.fqdn, recdepth, "fqdn", npref);
  sb << sep;
  rpc_print (sb, obj.seq_number, recdepth, "seq_number", npref);
  sb << sep;
  rpc_print (sb, obj.records, recdepth, "records", npref);
  sb << sep;
  rpc_print (sb, obj.account_hash, recdepth, "account_hash", npref);
  if (prefix)
    sb << prefix << "};\n";
  else
    sb << " }";
  return sb;
}
void
print_subdomain (const void *_objp, const strbuf *_sbp, int _recdepth,
                 const char *_name, const char *_prefix)
{
  rpc_print (_sbp ? *_sbp : warnx, *static_cast<const subdomain *> (_objp),
             _recdepth, _name, _prefix);
}
void
dump_subdomain (const subdomain *objp)
{
  rpc_print (warnx, *objp);
}

const strbuf &
rpc_print (const strbuf &sb, const account &obj, int recdepth,
           const char *name, const char *prefix)
{
  if (name) {
    if (prefix)
      sb << prefix;
    sb << "account " << name << " = ";
  };
  const char *sep;
  str npref;
  if (prefix) {
    npref = strbuf ("%s  ", prefix);
    sep = "";
    sb << "{\n";
  }
  else {
    sep = ", ";
    sb << "{ ";
  }
  rpc_print (sb, obj.key_hash, recdepth, "key_hash", npref);
  sb << sep;
  rpc_print (sb, obj.seq_num, recdepth, "seq_num", npref);
  sb << sep;
  rpc_print (sb, obj.suffix, recdepth, "suffix", npref);
  sb << sep;
  rpc_print (sb, obj.last_update, recdepth, "last_update", npref);
  sb << sep;
  rpc_print (sb, obj.soa_ttl, recdepth, "soa_ttl", npref);
  sb << sep;
  rpc_print (sb, obj.contact_email, recdepth, "contact_email", npref);
  sb << sep;
  rpc_print (sb, obj.subdomains, recdepth, "subdomains", npref);
  if (prefix)
    sb << prefix << "};\n";
  else
    sb << " }";
  return sb;
}
void
print_account (const void *_objp, const strbuf *_sbp, int _recdepth,
               const char *_name, const char *_prefix)
{
  rpc_print (_sbp ? *_sbp : warnx, *static_cast<const account *> (_objp),
             _recdepth, _name, _prefix);
}
void
dump_account (const account *objp)
{
  rpc_print (warnx, *objp);
}

#endif /* MAINTAINER*/
void *
attr_type_alloc ()
{
  return New attr_type;
}
bool_t
xdr_attr_type (XDR *xdrs, void *objp)
{
  switch (xdrs->x_op) {
  case XDR_ENCODE:
  case XDR_DECODE:
    return rpc_traverse (xdrs, *static_cast<attr_type *> (objp));
  case XDR_FREE:
    rpc_destruct (static_cast<attr_type *> (objp));
    return true;
  default:
    panic ("invalid xdr operation %d\n", xdrs->x_op);
  }
}

void *
record_attr_alloc ()
{
  return New record_attr;
}
bool_t
xdr_record_attr (XDR *xdrs, void *objp)
{
  switch (xdrs->x_op) {
  case XDR_ENCODE:
  case XDR_DECODE:
    return rpc_traverse (xdrs, *static_cast<record_attr *> (objp));
  case XDR_FREE:
    rpc_destruct (static_cast<record_attr *> (objp));
    return true;
  default:
    panic ("invalid xdr operation %d\n", xdrs->x_op);
  }
}

void *
record_alloc ()
{
  return New record;
}
bool_t
xdr_record (XDR *xdrs, void *objp)
{
  switch (xdrs->x_op) {
  case XDR_ENCODE:
  case XDR_DECODE:
    return rpc_traverse (xdrs, *static_cast<record *> (objp));
  case XDR_FREE:
    rpc_destruct (static_cast<record *> (objp));
    return true;
  default:
    panic ("invalid xdr operation %d\n", xdrs->x_op);
  }
}

void *
subdomain_alloc ()
{
  return New subdomain;
}
bool_t
xdr_subdomain (XDR *xdrs, void *objp)
{
  switch (xdrs->x_op) {
  case XDR_ENCODE:
  case XDR_DECODE:
    return rpc_traverse (xdrs, *static_cast<subdomain *> (objp));
  case XDR_FREE:
    rpc_destruct (static_cast<subdomain *> (objp));
    return true;
  default:
    panic ("invalid xdr operation %d\n", xdrs->x_op);
  }
}

void *
account_alloc ()
{
  return New account;
}
bool_t
xdr_account (XDR *xdrs, void *objp)
{
  switch (xdrs->x_op) {
  case XDR_ENCODE:
  case XDR_DECODE:
    return rpc_traverse (xdrs, *static_cast<account *> (objp));
  case XDR_FREE:
    rpc_destruct (static_cast<account *> (objp));
    return true;
  default:
    panic ("invalid xdr operation %d\n", xdrs->x_op);
  }
}

