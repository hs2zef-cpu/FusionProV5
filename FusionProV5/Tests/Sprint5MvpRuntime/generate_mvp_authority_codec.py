#!/usr/bin/env python3
"""Generate the narrow, field-explicit MVP authority-record codec.

The generated MQL has no reflection or generic object serialization.  This
build-time script reads the two authorized root DTOs and emits one strict
encoder/decoder function per transitively contained struct.
"""

from __future__ import annotations

import re
from pathlib import Path


REPO = Path(__file__).resolve().parents[3]
CONTRACT_DIRS = (
    REPO / "FusionProV5" / "ExecutionLayer" / "Contracts",
    REPO / "FusionProV5" / "ProductionArchitecture",
)
OUTPUT = (
    REPO
    / "FusionProV5"
    / "ExecutionLayer"
    / "RuntimeAuthority"
    / "SW_V5_S5_MvpAuthorityRecordCodec.mqh"
)
ROOTS = (
    "SWV5S5_ProducerTrustAnchor",
    "SWV5S5_ProducerTrustRecord",
    "SWV5S5_SubmissionAuthorityRecord",
)
PRIMITIVES = {"string", "int", "uint", "ulong", "long", "double", "bool", "datetime"}


def source_text() -> str:
    return "\n".join(
        path.read_text(encoding="utf-8-sig")
        for directory in CONTRACT_DIRS
        for path in sorted(directory.glob("*.mqh"))
    )


def parse_structs(text: str) -> dict[str, list[tuple[str, str, bool]]]:
    structs: dict[str, list[tuple[str, str, bool]]] = {}
    for name, body in re.findall(r"struct\s+(\w+)\s*\{(.*?)\};", text, re.S):
        fields: list[tuple[str, str, bool]] = []
        for field_type, declarations in re.findall(
            r"^\s*([A-Za-z_]\w*)\s+([^;]+);", body, re.M
        ):
            for declaration in declarations.split(","):
                match = re.match(r"\s*([A-Za-z_]\w*)(\[\])?", declaration.strip())
                if match:
                    fields.append((field_type, match.group(1), bool(match.group(2))))
        structs[name] = fields
    return structs


def parse_enums(text: str) -> dict[str, int]:
    maxima: dict[str, int] = {}
    for name, body in re.findall(r"enum\s+(\w+)\s*\{(.*?)\};", text, re.S):
        body = re.sub(r"//.*", "", body)
        values = [part.strip() for part in body.split(",") if part.strip()]
        numeric: list[int] = []
        next_value = 0
        for value in values:
            if "=" in value:
                expression = value.split("=", 1)[1].strip()
                if not re.fullmatch(r"-?\d+", expression):
                    numeric = []
                    break
                next_value = int(expression)
            numeric.append(next_value)
            next_value += 1
        if numeric and numeric == list(range(min(numeric), max(numeric) + 1)):
            maxima[name] = max(numeric)
    return maxima


def closure_order(
    structs: dict[str, list[tuple[str, str, bool]]]
) -> list[str]:
    ordered: list[str] = []
    visiting: set[str] = set()
    visited: set[str] = set()

    def visit(name: str) -> None:
        if name in visited:
            return
        if name in visiting:
            raise RuntimeError(f"recursive struct is unsupported: {name}")
        if name not in structs:
            raise RuntimeError(f"missing struct definition: {name}")
        visiting.add(name)
        for field_type, _, _ in structs[name]:
            if field_type in structs:
                visit(field_type)
        visiting.remove(name)
        visited.add(name)
        ordered.append(name)

    for root in ROOTS:
        visit(root)
    return ordered


def encode_line(field_type: str, name: str, is_array: bool) -> list[str]:
    if is_array:
        lines = [
            f'   if(!SWV5S5_CanonicalUInt("{name}_count",(ulong)ArraySize(v.{name}),f)) return false; body+=f;',
            f"   for(int i=0;i<ArraySize(v.{name});i++)",
            "   {",
            f"      if(!SWV5S5_MvpCodecEncode_{field_type}(v.{name}[i],nested) ||",
            f'         !SWV5S5_CanonicalNested("{name}_"+IntegerToString(i),nested,f)) return false;',
            "      body+=f;",
            "   }",
        ]
        return lines
    value = f"v.{name}"
    if field_type == "string":
        call = f'SWV5S5_CanonicalString("{name}",{value},f)'
    elif field_type in {"int", "long", "datetime"} or field_type not in PRIMITIVES:
        call = f'SWV5S5_CanonicalInt("{name}",{value},f)'
    elif field_type in {"uint", "ulong"}:
        call = f'SWVV5S5_CanonicalUInt("{name}",{value},f)'
    elif field_type == "double":
        call = f'SWV5S5_CanonicalDouble("{name}",{value},f)'
    elif field_type == "bool":
        call = f'SWV5S5_CanonicalBool("{name}",{value},f)'
    else:
        call = "false"
    if field_type.startswith("SWV5") and field_type in STRUCTS:
        return [
            f"   if(!SWV5S5_MvpCodecEncode_{field_type}({value},nested) ||",
            f'      !SWV5S5_CanonicalNested("{name}",nested,f)) return false; body+=f;',
        ]
    return [f"   if(!{call}) return false; body+=f;"]


def decode_lines(field_type: str, name: str, is_array: bool, enum_max: dict[str, int]) -> list[str]:
    if is_array:
        return [
            f'   if(!reader.ReadUnsigned("{name}_count",count) || count>100000) return false;',
            f"   ArrayResize(v.{name},(int)count);",
            f"   for(ulong i=0;i<count;i++)",
            "   {",
            f'      if(!reader.ReadNested("{name}_"+IntegerToString((long)i),nested) ||',
            f"         !SWV5S5_MvpCodecDecode_{field_type}(nested,v.{name}[(int)i])) return false;",
            "   }",
        ]
    target = f"v.{name}"
    if field_type in STRUCTS:
        return [
            f'   if(!reader.ReadNested("{name}",nested) ||',
            f"      !SWV5S5_MvpCodecDecode_{field_type}(nested,{target})) return false;",
        ]
    if field_type == "string":
        return [f'   if(!reader.ReadString("{name}",{target})) return false;']
    if field_type in {"uint", "ulong"}:
        return [f'   if(!reader.ReadUnsigned("{name}",{target})) return false;']
    if field_type == "long":
        return [f'   if(!reader.ReadInteger("{name}",{target})) return false;']
    if field_type == "double":
        return [f'   if(!reader.ReadDouble("{name}",{target})) return false;']
    if field_type == "bool":
        return [f'   if(!reader.ReadBool("{name}",{target})) return false;']
    if field_type == "int":
        return [
            f'   if(!reader.ReadInteger("{name}",number) || number<-2147483648 || number>2147483647) return false;',
            f"   {target}=(int)number;",
        ]
    if field_type == "datetime":
        return [
            f'   if(!reader.ReadInteger("{name}",number)) return false;',
            f"   {target}=(datetime)number;",
        ]
    if field_type not in enum_max:
        raise RuntimeError(f"enum values are not a contiguous strict range: {field_type}")
    return [
        f'   if(!reader.ReadInteger("{name}",number) || number<0 || number>{enum_max[field_type]}) return false;',
        f"   {target}=({field_type})number;",
    ]


def generate() -> str:
    text = source_text()
    global STRUCTS
    STRUCTS = parse_structs(text)
    enum_max = parse_enums(text)
    order = closure_order(STRUCTS)
    lines = [
        "// GENERATED BY Tests/Sprint5MvpRuntime/generate_mvp_authority_codec.py",
        "// MVP RUNTIME AUTHORITY PERSISTENCE ONLY. NO BROKER ACCESS.",
        "#ifndef SW_V5_S5_MVP_AUTHORITY_RECORD_CODEC_MQH",
        "#define SW_V5_S5_MVP_AUTHORITY_RECORD_CODEC_MQH",
        "",
        '#include "SW_V5_S5_MvpDemoAuthorityProviders.mqh"',
        "",
        'const string SWV5S5_MVP_TRUST_PHYSICAL_FORMAT="SWV5-MVP-TRUST-PHYSICAL-V1";',
        'const string SWV5S5_MVP_SUBMISSION_PHYSICAL_FORMAT="SWV5-MVP-SUBMISSION-PHYSICAL-V1";',
        "",
        "class SWV5S5_MvpCodecReader",
        "{",
        "private:",
        "   string m_text;",
        "   int m_offset;",
        "public:",
        "   void Init(const string text) { m_text=text; m_offset=0; }",
        "   bool AtEnd(void) const { return m_offset==StringLen(m_text); }",
        "   bool ReadRaw(const string name,const string type,string &value)",
        "   {",
        "      const string prefix=name+\":\"+type+\":\";",
        "      if(StringSubstr(m_text,m_offset,StringLen(prefix))!=prefix) return false;",
        "      int cursor=m_offset+StringLen(prefix),first=cursor,total=StringLen(m_text);",
        "      while(cursor<total)",
        "      {",
        "         const ushort c=StringGetCharacter(m_text,cursor);",
        "         if(c==58) break; if(c<48 || c>57) return false; cursor++;",
        "      }",
        "      if(cursor==first || cursor>=total) return false;",
        "      const string length_text=StringSubstr(m_text,first,cursor-first);",
        "      if(StringLen(length_text)>1 && StringGetCharacter(length_text,0)==48) return false;",
        "      const long declared=StringToInteger(length_text);",
        "      const int payload_start=cursor+1;",
        "      if(declared<0 || declared>2147483647 || declared>(long)(total-payload_start)*4) return false;",
        "      int payload_end=payload_start; long consumed=0;",
        "      while(consumed<declared)",
        "      {",
        "         if(payload_end>=total) return false;",
        "         uint cp=(uint)StringGetCharacter(m_text,payload_end++);",
        "         if(cp>=0xD800 && cp<=0xDBFF)",
        "         {",
        "            if(payload_end>=total) return false;",
        "            const uint low=(uint)StringGetCharacter(m_text,payload_end++);",
        "            if(low<0xDC00 || low>0xDFFF) return false;",
        "            cp=0x10000+((cp-0xD800)<<10)+(low-0xDC00);",
        "         }",
        "         else if(cp>=0xDC00 && cp<=0xDFFF) return false;",
        "         const int width=(cp<=0x7F ? 1 : (cp<=0x7FF ? 2 : (cp<=0xFFFF ? 3 : 4)));",
        "         if(consumed+(long)width>declared) return false; consumed+=(long)width;",
        "      }",
        "      value=StringSubstr(m_text,payload_start,payload_end-payload_start);",
        "      m_offset=payload_end; return true;",
        "   }",
        "   bool ReadString(const string name,string &value) { return ReadRaw(name,\"s\",value); }",
        "   bool ReadNested(const string name,string &value) { return ReadRaw(name,\"x\",value); }",
        "   bool ReadInteger(const string name,long &value)",
        "   { string raw; if(!ReadRaw(name,\"i\",raw) || raw==\"\") return false;",
        "     value=StringToInteger(raw); return IntegerToString(value)==raw; }",
        "   bool ReadUnsigned(const string name,ulong &value)",
        "   { string raw; if(!ReadRaw(name,\"u\",raw) || raw==\"\" ||",
        "        (StringLen(raw)>1 && StringGetCharacter(raw,0)==48)) return false;",
        "     value=0; for(int i=0;i<StringLen(raw);i++)",
        "     { const ushort c=StringGetCharacter(raw,i); if(c<48 || c>57) return false;",
        "       const ulong digit=(ulong)(c-48);",
        "       if(value>1844674407370955161 || (value==1844674407370955161 && digit>5)) return false;",
        "       value=value*10+digit; }",
        "     return StringFormat(\"%I64u\",value)==raw; }",
        "   bool ReadUnsigned(const string name,uint &value)",
        "   { ulong parsed=0; if(!ReadUnsigned(name,parsed) || parsed>4294967295) return false; value=(uint)parsed; return true; }",
        "   bool ReadDouble(const string name,double &value)",
        "   { string raw; if(!ReadRaw(name,\"d\",raw) || raw==\"\") return false; value=StringToDouble(raw);",
        "     if(!MathIsValidNumber(value)) return false; const double normalized=(MathAbs(value)<0.00000000000000005 ? 0.0 : value);",
        "     return DoubleToString(normalized,16)==raw; }",
        "   bool ReadBool(const string name,bool &value)",
        "   { string raw; if(!ReadRaw(name,\"b\",raw) || (raw!=\"0\" && raw!=\"1\")) return false; value=(raw==\"1\"); return true; }",
        "};",
        "",
    ]
    for struct_name in order:
        lines.extend(
            [
                f"bool SWV5S5_MvpCodecEncode_{struct_name}(const {struct_name} &v,string &body)",
                "{",
                '   body=""; string f="",nested="";',
            ]
        )
        for field_type, name, is_array in STRUCTS[struct_name]:
            lines.extend(encode_line(field_type, name, is_array))
        lines.extend(["   return true;", "}", ""])
        lines.extend(
            [
                f"bool SWV5S5_MvpCodecDecode_{struct_name}(const string text,{struct_name} &v)",
                "{",
                "   ZeroMemory(v); SWV5S5_MvpCodecReader reader; reader.Init(text);",
                '   string nested=""; long number=0; ulong count=0;',
            ]
        )
        for field_type, name, is_array in STRUCTS[struct_name]:
            lines.extend(decode_lines(field_type, name, is_array, enum_max))
        lines.extend(["   return reader.AtEnd();", "}", ""])

    lines.extend(
        [
            "bool SWV5S5_MvpEncodeProducerTrustPhysical(const SWV5S5_ProducerTrustRecord &record,",
            "                                                const SWV5S5_ProducerTrustAnchor &anchor,",
            "                                                const string operator_id,",
            "                                                const string authentication_reference,string &payload)",
            "{",
            '   string body,anchor_body,format_field,record_field,anchor_field,operator_field,auth_field; payload="";',
            "   if(operator_id==\"\" || authentication_reference==\"\" ||",
            "      !SWV5S5_MvpCodecEncode_SWV5S5_ProducerTrustRecord(record,body) ||",
            "      !SWV5S5_MvpCodecEncode_SWV5S5_ProducerTrustAnchor(anchor,anchor_body) ||",
            '      !SWV5S5_CanonicalString("physical_format",SWV5S5_MVP_TRUST_PHYSICAL_FORMAT,format_field) ||',
            '      !SWV5S5_CanonicalNested("record",body,record_field) ||',
            '      !SWV5S5_CanonicalNested("anchor",anchor_body,anchor_field) ||',
            '      !SWV5S5_CanonicalString("operator_id",operator_id,operator_field) ||',
            '      !SWV5S5_CanonicalString("authentication_reference",authentication_reference,auth_field)) return false;',
            "   payload=format_field+record_field+anchor_field+operator_field+auth_field; return true;",
            "}",
            "",
            "bool SWV5S5_MvpDecodeProducerTrustPhysical(const string payload,SWV5S5_ProducerTrustRecord &record,",
            "                                                SWV5S5_ProducerTrustAnchor &anchor,",
            "                                                string &operator_id,string &authentication_reference)",
            "{",
            "   ZeroMemory(record); ZeroMemory(anchor); operator_id=\"\"; authentication_reference=\"\";",
            "   SWV5S5_MvpCodecReader reader; reader.Init(payload); string format,nested,anchor_nested,digest;",
            '   return reader.ReadString("physical_format",format) && format==SWV5S5_MVP_TRUST_PHYSICAL_FORMAT &&',
            '      reader.ReadNested("record",nested) && reader.ReadNested("anchor",anchor_nested) &&',
            '      reader.ReadString("operator_id",operator_id) && operator_id!="" &&',
            '      reader.ReadString("authentication_reference",authentication_reference) && authentication_reference!="" && reader.AtEnd() &&',
            "      SWV5S5_MvpCodecDecode_SWV5S5_ProducerTrustRecord(nested,record) &&",
            "      SWV5S5_MvpCodecDecode_SWV5S5_ProducerTrustAnchor(anchor_nested,anchor) &&",
            "      anchor.issuer_identity==record.issuer_identity && anchor.issuer_policy_id==record.issuer_policy_id &&",
            "      anchor.current_authority_record_id==record.authority_record_id &&",
            "      anchor.current_authority_generation==record.authority_generation && anchor.trust_anchor_id!=\"\" &&",
            "      SWV5S5_DeriveProducerTrustDigest(record,digest) && digest==record.record_digest;",
            "}",
            "",
            "bool SWV5S5_MvpEncodeSubmissionPhysical(const SWV5S5_SubmissionAuthorityRecord &record,string &payload)",
            "{",
            '   string body,format_field,record_field; payload="";',
            "   if(!SWV5S5_MvpCodecEncode_SWV5S5_SubmissionAuthorityRecord(record,body) ||",
            '      !SWV5S5_CanonicalString("physical_format",SWV5S5_MVP_SUBMISSION_PHYSICAL_FORMAT,format_field) ||',
            '      !SWV5S5_CanonicalNested("record",body,record_field)) return false;',
            "   payload=format_field+record_field; return true;",
            "}",
            "",
            "bool SWV5S5_MvpDecodeSubmissionPhysical(const string payload,SWV5S5_SubmissionAuthorityRecord &record)",
            "{",
            "   ZeroMemory(record); SWV5S5_MvpCodecReader reader; reader.Init(payload); string format,nested,digest,permit_digest,snapshot_digest;",
            '   if(!reader.ReadString("physical_format",format) || format!=SWV5S5_MVP_SUBMISSION_PHYSICAL_FORMAT ||',
            '      !reader.ReadNested("record",nested) || !reader.AtEnd() ||',
            "      !SWV5S5_MvpCodecDecode_SWV5S5_SubmissionAuthorityRecord(nested,record) ||",
            "      !SWV5S5_DerivePermitDigest(record.permit,permit_digest) || permit_digest!=record.permit.permit_digest ||",
            "      !SWV5S5_DeriveDurableSubmissionAuthorityDigest(record,digest) || digest!=record.durable_record_digest) return false;",
            "   if(record.state!=SWV5S5_COMMITTED_NOT_INVOKED)",
            "   { SWV5S5_AdmissionSnapshot copy=record.admission_snapshot;",
            "     if(!SWV5S5_DeriveAdmissionSnapshotDigest(copy,snapshot_digest) || snapshot_digest!=record.admission_snapshot_digest) return false; }",
            "   return true;",
            "}",
            "",
            "#endif // SW_V5_S5_MVP_AUTHORITY_RECORD_CODEC_MQH",
            "",
        ]
    )
    generated = "\n".join(lines)
    if "SWVV5S5_" in generated:
        generated = generated.replace("SWVV5S5_", "SWV5S5_")
    return generated


if __name__ == "__main__":
    OUTPUT.write_text(generate(), encoding="utf-8", newline="\n")
    print(f"generated {OUTPUT}")
