// SPDX-License-Identifier: GPL-3.0-only
// Read-only metadata/IL inspection. Does not load or execute original game code.
using System;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Reflection.Emit;
using System.Reflection.Metadata;
using System.Reflection.Metadata.Ecma335;
using System.Reflection.PortableExecutable;
using System.Collections.Generic;
class InspectAssembly {
 static MetadataReader r;
 static string Name(EntityHandle h) {
  if(h.IsNil)return "nil";
  switch(h.Kind){
   case HandleKind.TypeDefinition:var t=r.GetTypeDefinition((TypeDefinitionHandle)h);return r.GetString(t.Namespace)+"."+r.GetString(t.Name);
   case HandleKind.TypeReference:var tr=r.GetTypeReference((TypeReferenceHandle)h);return r.GetString(tr.Namespace)+"."+r.GetString(tr.Name);
   case HandleKind.FieldDefinition:var f=r.GetFieldDefinition((FieldDefinitionHandle)h);return Name(f.GetDeclaringType())+"::"+r.GetString(f.Name);
   case HandleKind.MethodDefinition:var m=r.GetMethodDefinition((MethodDefinitionHandle)h);return Name(m.GetDeclaringType())+"::"+r.GetString(m.Name);
   case HandleKind.MemberReference:var mr=r.GetMemberReference((MemberReferenceHandle)h);return Name(mr.Parent)+"::"+r.GetString(mr.Name);
   case HandleKind.MethodSpecification:return Name(r.GetMethodSpecification((MethodSpecificationHandle)h).Method);
   default:return h.Kind+":"+MetadataTokens.GetToken(h).ToString("x8");
  }
 }
 static void Main(string[] args){using var pe=new PEReader(File.OpenRead(args[0]));r=pe.GetMetadataReader();
  Console.WriteLine("MVID="+r.GetGuid(r.GetModuleDefinition().Mvid));
  if(args.Length>1 && args[1].StartsWith("0x")){
   var h=MetadataTokens.MethodDefinitionHandle(Convert.ToInt32(args[1].Substring(2),16)&0xffffff);var m=r.GetMethodDefinition(h);
   Console.WriteLine(Name(h));var b=pe.GetMethodBody(m.RelativeVirtualAddress).GetILBytes();
   var ops=typeof(OpCodes).GetFields().Where(f=>f.FieldType==typeof(OpCode)).Select(f=>(OpCode)f.GetValue(null)).ToDictionary(o=>(ushort)o.Value);
   for(int i=0;i<b.Length;){int at=i;ushort c=b[i++];if(c==254)c=(ushort)(0xfe00|b[i++]);var o=ops[c];string v="";int n=0;
    switch(o.OperandType){
     case OperandType.InlineField:case OperandType.InlineMethod:case OperandType.InlineType:case OperandType.InlineTok:case OperandType.InlineSig:n=4;v=Name(MetadataTokens.EntityHandle(BitConverter.ToInt32(b,i)));break;
     case OperandType.InlineString:n=4;v="\""+r.GetUserString(MetadataTokens.UserStringHandle(BitConverter.ToInt32(b,i)&0xffffff))+"\"";break;
     case OperandType.InlineI:n=4;v=BitConverter.ToInt32(b,i).ToString();break;
     case OperandType.InlineI8:n=8;v=BitConverter.ToInt64(b,i).ToString();break;
     case OperandType.ShortInlineR:n=4;v=BitConverter.ToSingle(b,i).ToString();break;
     case OperandType.InlineR:n=8;v=BitConverter.ToDouble(b,i).ToString();break;
     case OperandType.ShortInlineBrTarget:n=1;v=(i+1+(sbyte)b[i]).ToString("x4");break;
     case OperandType.InlineBrTarget:n=4;v=(i+4+BitConverter.ToInt32(b,i)).ToString("x4");break;
     case OperandType.ShortInlineI:case OperandType.ShortInlineVar:n=1;v=b[i].ToString();break;
     case OperandType.InlineVar:n=2;v=BitConverter.ToUInt16(b,i).ToString();break;
     case OperandType.InlineSwitch:int count=BitConverter.ToInt32(b,i);n=4+count*4;v="switch "+count;break;
    }i+=n;Console.WriteLine(at.ToString("x4")+": "+o.Name+" "+v);
   }return;
  }
  foreach(var h in r.TypeDefinitions){string name=Name(h);if(!args.Skip(1).Any(x=>name==x || name.EndsWith("."+x)))continue;var t=r.GetTypeDefinition(h);
   Console.WriteLine("TYPE "+name+" base "+Name(t.BaseType));
   foreach(var f in t.GetFields()){var x=r.GetFieldDefinition(f);string constant="";if(!x.GetDefaultValue().IsNil){var k=r.GetConstant(x.GetDefaultValue());constant=k.TypeCode==ConstantTypeCode.String?System.Text.Encoding.Unicode.GetString(r.GetBlobBytes(k.Value)):Convert.ToHexString(r.GetBlobBytes(k.Value));}Console.WriteLine("FIELD "+MetadataTokens.GetToken(f).ToString("x8")+" "+x.Attributes+" "+r.GetString(x.Name)+" sig="+Convert.ToHexString(r.GetBlobBytes(x.Signature))+" "+constant);}
   foreach(var m in t.GetMethods()){var x=r.GetMethodDefinition(m);Console.WriteLine("METHOD "+MetadataTokens.GetToken(m).ToString("x8")+" "+x.Attributes+" "+r.GetString(x.Name)+" sig="+Convert.ToHexString(r.GetBlobBytes(x.Signature)));}
   foreach(var e in t.GetEvents()){var x=r.GetEventDefinition(e);Console.WriteLine("EVENT "+r.GetString(x.Name)+" "+Name(x.Type));}
  }
 }
}
