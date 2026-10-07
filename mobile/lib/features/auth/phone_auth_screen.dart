import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});
  @override State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}
class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final phone = TextEditingController(), otp = TextEditingController();
  bool sent=false, busy=false; String? error;
  AuthService get auth => AuthService(Supabase.instance.client);
  @override void dispose(){phone.dispose(); otp.dispose(); super.dispose();}
  Future<void> send() async {
    setState(()=>busy=true); try { await auth.sendPhoneOtp(phone.text); if(mounted)setState(()=>sent=true); }
    catch(e){if(mounted)setState(()=>error=e.toString());} finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> verify() async {
    setState(()=>busy=true); try { await auth.verifyPhoneOtp(phone:phone.text,token:otp.text); }
    catch(e){if(mounted)setState(()=>error=e.toString());} finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    body:SafeArea(child:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:ConstrainedBox(
      constraints:const BoxConstraints(maxWidth:420),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('RDS Nearby',style:TextStyle(fontSize:30,fontWeight:FontWeight.w700)),
        SizedBox(height:8),Text('जो चाहिए, पहले अपने आस-पास देखो।'),SizedBox(height:32),
        TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'Mobile number',hintText:'10-digit Indian mobile number',border:OutlineInputBorder())),
        if(sent) ...[const SizedBox(height:16),TextField(controller:otp,keyboardType:TextInputType.number,maxLength:6,decoration:const InputDecoration(labelText:'OTP',border:OutlineInputBorder()))],
        if(error!=null) ...[const SizedBox(height:12),Text(error!,style:TextStyle(color:Colors.red))],
        const SizedBox(height:16),SizedBox(width:double.infinity,child:FilledButton(onPressed:busy?null:(sent?verify:send),child:Text(busy?'Please wait…':(sent?'Verify OTP':'Send OTP')))),
      ]))))));
}
