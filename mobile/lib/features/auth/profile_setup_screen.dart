import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import '../../core/referral_deep_link_service.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});
  @override State<ProfileSetupScreen> createState()=>_ProfileSetupScreenState();
}
class _ProfileSetupScreenState extends State<ProfileSetupScreen>{
  final name=TextEditingController(); String? role,error; bool busy=false;
  AuthService get auth=>AuthService(Supabase.instance.client);
  @override void dispose(){name.dispose();super.dispose();}
  Future<void> save() async {
    if(name.text.trim().length<2){setState(()=>error='Enter your name.');return;}
    if(role==null){setState(()=>error='Choose Customer or Merchant.');return;}
    setState(()=>busy=true);
    try{await auth.completeProfile(name:name.text);await auth.setInitialRole(role!);await ReferralDeepLinkService.instance.submitPendingReferral();}
    catch(e){if(mounted)setState(()=>error=e.toString());}finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Set up your profile')),
    body:Padding(padding:const EdgeInsets.all(24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('Welcome to RDS Nearby',style:TextStyle(fontSize:26,fontWeight:FontWeight.w700)),
      const SizedBox(height:8),const Text('Tell us who you are. Business details come next.'),
      const SizedBox(height:24),TextField(controller:name,decoration:const InputDecoration(labelText:'Your name',border:OutlineInputBorder())),
      const SizedBox(height:24),const Text('Choose your mode'),
      const SizedBox(height:8),
      RadioListTile<String>(value:'customer',groupValue:role,onChanged:(v)=>setState(()=>role=v),title:const Text('Customer'),subtitle:const Text('Find nearby shops, offers and services.')),
      RadioListTile<String>(value:'merchant',groupValue:role,onChanged:(v)=>setState(()=>role=v),title:const Text('Merchant'),subtitle:const Text('List your business and grow local customers.')),
      if(error!=null)Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error)),
      const SizedBox(height:16),SizedBox(width:double.infinity,child:FilledButton(onPressed:busy?null:save,child:Text(busy?'Saving…':'Continue'))),
    ])));
}
