import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_tesseract_ocr/flutter_tesseract_ocr.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_image_renderer/pdf_image_renderer.dart';

const bg=Color(0xFF0B1020), card=Color(0xFF151D33), accent=Color(0xFF5DE4C7), accent2=Color(0xFF7C83FD), soft=Color(0xFF9BA8C4), chord=Color(0xFFFFD166);
ThemeData appTheme(int t){
  const seeds=[accent2,Color(0xFF2F80ED),Color(0xFFE85D75),Color(0xFFFFA94D),Color(0xFF20C997)];
  if(t==1)return ThemeData(brightness:Brightness.light,colorScheme:ColorScheme.fromSeed(seedColor:seeds[t],brightness:Brightness.light),scaffoldBackgroundColor:Color(0xFFF4F6FA),useMaterial3:true);
  return ThemeData(brightness:Brightness.dark,colorScheme:ColorScheme.fromSeed(seedColor:seeds[t],brightness:Brightness.dark),scaffoldBackgroundColor:t==3?Color(0xFF1B1410):bg,useMaterial3:true);
}
String themeName(int t)=>['לילה סגול','בהיר','כחול עמוק','חם','טורקיז'][t];

void main() async { WidgetsFlutterBinding.ensureInitialized(); final s=Store(); await s.load(); runApp(App(store:s)); }

class App extends StatelessWidget {
  final Store store;
  const App({super.key,required this.store});
  @override Widget build(BuildContext c)=>AnimatedBuilder(
    animation:store,
    builder:(_,__)=>MaterialApp(
      debugShowCheckedModeBanner:false,title:'במה',
      theme:appTheme(store.theme),
      home:Directionality(textDirection:TextDirection.rtl,child:Home(store:store)),
    ),
  );
}

class Song {
  String id,title,artist,style,key,text,folderId;
  Song({required this.id,required this.title,this.artist='',this.style='כללי',this.key='C',this.text='',this.folderId=''});
  Map<String,dynamic> toJson()=>{'id':id,'title':title,'artist':artist,'style':style,'key':key,'text':text,'folderId':folderId};
  factory Song.fromJson(Map<String,dynamic> j)=>Song(id:j['id']??uid(),title:j['title']??'שיר',artist:j['artist']??'',style:j['style']??'כללי',key:j['key']??'C',text:j['text']??'',folderId:j['folderId']??'');
}
class Setlist {
  String id,name,folderId; List<String> ids,names;
  Setlist({required this.id,required this.name,this.ids=const[],this.names=const[],this.folderId=''}) ;
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'ids':ids,'names':names,'folderId':folderId};
  factory Setlist.fromJson(Map<String,dynamic> j)=>Setlist(id:j['id']??uid(),name:j['name']??'פלייליסט',ids:List<String>.from(j['ids']??[]),names:List<String>.from(j['names']??[]),folderId:j['folderId']??'');
}
class Folder {
  String id,name,parentId;
  Folder({required this.id,required this.name,this.parentId='' });
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'parentId':parentId};
  factory Folder.fromJson(Map<String,dynamic> j)=>Folder(id:j['id']??uid(),name:j['name']??'תיקייה',parentId:j['parentId']??'');
}
String uid()=>DateTime.now().microsecondsSinceEpoch.toString()+math.Random().nextInt(999).toString();

class Store extends ChangeNotifier {
  List<Song> songs=[]; List<Setlist> lists=[]; List<Folder> folders=[]; List<String> styles=['חסידי','שקט','קצבי','מזרחי','כללי']; int theme=0;
  Future<void> load() async {
    final p=await SharedPreferences.getInstance(), raw=p.getString('bama_v4') ?? p.getString('bama_v3');
    if(raw==null){ songs=demo(); lists=[Setlist(id:uid(),name:'הופעה – יום שישי',ids:songs.map((x)=>x.id).toList()),Setlist(id:uid(),name:'חזרות',ids:songs.take(2).map((x)=>x.id).toList())]; await save(); }
    else { final j=jsonDecode(raw); songs=(j['songs'] as List? ?? []).map((x)=>Song.fromJson(x)).toList(); lists=(j['lists'] as List? ?? []).map((x)=>Setlist.fromJson(x)).toList(); folders=(j['folders'] as List? ?? []).map((x)=>Folder.fromJson(x)).toList(); styles=List<String>.from(j['styles']??styles); theme=j['theme']??0; for(final l in lists){if(l.names.isEmpty&&l.ids.isNotEmpty){l.names=l.ids.map((id)=>song(id)?.title??'').where((x)=>x.isNotEmpty).toList();}} }
  }
  Future<void> save() async { final p=await SharedPreferences.getInstance(); await p.setString('bama_v4',jsonEncode({'songs':songs.map((x)=>x.toJson()).toList(),'lists':lists.map((x)=>x.toJson()).toList(),'folders':folders.map((x)=>x.toJson()).toList(),'styles':styles,'theme':theme})); notifyListeners(); }
  Song? song(String id){for(final s in songs){if(s.id==id)return s;}return null;}
  Future<void> putSong(Song s) async { final i=songs.indexWhere((x)=>x.id==s.id); if(i<0)songs.add(s);else songs[i]=s; if(!styles.contains(s.style))styles.add(s.style); await save(); }
Future<void> deleteSong(String id) async {songs.removeWhere((s)=>s.id==id);for(final l in lists){l.ids.remove(id);}await save();}
Future<void> renameList(Setlist l,String n) async {l.name=n;await save();}
Future<void> deleteList(Setlist l) async {lists.removeWhere((x)=>x.id==l.id);await save();}
Future<void> addStyle(String s) async {s=s.trim();if(s.isNotEmpty&&!styles.contains(s)){styles.add(s);await save();}}
Future<void> deleteStyle(String s) async {if(styles.length<=1)return;styles.remove(s);for(final x in songs){if(x.style==s)x.style='כללי';}await save();}
Future<void> setTheme(int t) async {theme=t;await save();}
Future<void> addPlaylist(String n,{String folderId=''}) async {lists.add(Setlist(id:uid(),name:n,names:const[],folderId:folderId));await save();}
Future<void> addFolder(String n,{String parentId=''}) async {folders.add(Folder(id:uid(),name:n,parentId:parentId));await save();}
Future<void> deleteFolder(Folder f) async {for(final x in lists){if(x.folderId==f.id)x.folderId='';}for(final x in folders){if(x.parentId==f.id)x.parentId='';}folders.removeWhere((x)=>x.id==f.id);await save();}
Future<void> movePlaylist(Setlist l,String folderId) async {l.folderId=folderId;await save();}
Future<void> moveSong(Song s,String folderId) async {s.folderId=folderId;await save();}
Future<void> renameFolder(Folder f,String n) async {f.name=n;await save();}
Future<void> renamePlaylist(Setlist l,String n) async {l.name=n;await save();}
Future<void> reorderPlaylistNames(Setlist l,int oldIndex,int newIndex) async {if(newIndex>oldIndex)newIndex--;final a=List<String>.from(l.names);final v=a.removeAt(oldIndex);a.insert(newIndex,v);l.names=a;await save();}
Future<void> removePlaylistName(Setlist l,int i) async {final a=List<String>.from(l.names);a.removeAt(i);l.names=a;await save();}
  Future<void> addList(String n) async {lists.add(Setlist(id:uid(),name:n));await save();}
  Future<void> toggle(String lid,String sid) async {final l=lists.firstWhere((x)=>x.id==lid);if(l.ids.contains(sid))l.ids.remove(sid);else l.ids.add(sid);await save();}
}
List<Song> demo()=>[
 Song(id:uid(),title:'רגעים',artist:'הדגמה',style:'חסידי',key:'Am',text:'# בית\n[Am]זה הבית הראשון\n[F]שרים ביחד\n\n# פזמון\n[C]כולם שרים עכשיו\n[G]והלב עולה\n\n# מעבר\n[Dm]עוברים בשקט\n[E]וחוזרים'),
 Song(id:uid(),title:'עוד יום',artist:'הדגמה',style:'שקט',key:'C',text:'# בית\nC              Am\nעוד יום מתחיל כאן\nF              G\nואנחנו ממשיכים\n\n# פזמון\n[C]עוד יום עוד אור\n[Am]עוד סיבה לשיר'),
 Song(id:uid(),title:'קצב הלילה',style:'קצבי',key:'G',text:'# בית\nG D Em C\nהלילה מתחיל עכשיו\n\n# פזמון\n[G]בואו נרים את הקצב\n[D]ונשיר ביחד'),
];

class LogoMark extends StatelessWidget{
  final double size;
  const LogoMark({super.key,this.size=52});
  @override Widget build(BuildContext c)=>SizedBox(width:size,height:size,child:SvgPicture.asset('assets/logo.svg',semanticsLabel:'במה',fit:BoxFit.contain));
}
class Home extends StatefulWidget {
  final Store store; const Home({super.key,required this.store});
  @override State<Home> createState()=>_HomeState();
}
class _HomeState extends State<Home>{
  int tab=0;
  @override Widget build(BuildContext c)=>AnimatedBuilder(animation:widget.store,builder:(_,__)=>Scaffold(
    body:SafeArea(child:IndexedStack(index:tab,children:[Dashboard(store:widget.store),Lists(store:widget.store),Songs(store:widget.store),SettingsPage(store:widget.store)])),
    bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[
      NavigationDestination(icon:Icon(Icons.dashboard_outlined),selectedIcon:Icon(Icons.dashboard),label:'הופעות'),
      NavigationDestination(icon:Icon(Icons.view_list_outlined),selectedIcon:Icon(Icons.view_list),label:'רשימות'),
      NavigationDestination(icon:Icon(Icons.library_music_outlined),selectedIcon:Icon(Icons.library_music),label:'שירים'),
      NavigationDestination(icon:Icon(Icons.settings_outlined),selectedIcon:Icon(Icons.settings),label:'הגדרות'),
    ]),
  ));
}

class Dashboard extends StatelessWidget{
  final Store store;
  const Dashboard({super.key,required this.store});
  @override Widget build(BuildContext c){
    return Scaffold(
      appBar:AppBar(title:Row(children:const[LogoMark(size:38),SizedBox(width:10),Text('במה',style:TextStyle(fontWeight:FontWeight.w900))])),
      body:ListView(
        padding:const EdgeInsets.all(16),
        children:[
          const Text('מוכנים להופעה?',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),
          const SizedBox(height:6),
          const Text('ניהול מהיר של הופעות, רשימות ושירים.',style:TextStyle(color:soft)),
          const SizedBox(height:18),
          Row(children:[
            Expanded(child:Card(child:ListTile(leading:const Icon(Icons.view_list,color:accent),title:Text(store.lists.length.toString(),style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900)),subtitle:const Text('רשימות')))),
            const SizedBox(width:10),
            Expanded(child:Card(child:ListTile(leading:const Icon(Icons.music_note,color:accent),title:Text(store.songs.length.toString(),style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900)),subtitle:const Text('שירים')))),
          ]),
          const SizedBox(height:12),
          const Text('רשימות אחרונות',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
          const SizedBox(height:7),
          ...store.lists.take(5).map((l)=>Card(child:ListTile(
            leading:const Icon(Icons.queue_music,color:accent),
            title:Text(l.name,style:const TextStyle(fontWeight:FontWeight.bold)),
            subtitle:Text(l.ids.length.toString()+' שירים'),
            trailing:const Icon(Icons.chevron_left),
            onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>PlaylistView(store:store,playlist:l))),
          ))),
        ],
      ),
    );
  }
}
class Lists extends StatelessWidget{
  final Store store; const Lists({super.key,required this.store});
  Future<void> importPlaylist(BuildContext c)async{
    final r=await FilePicker.platform.pickFiles(withData:true,type:FileType.custom,allowedExtensions:['txt','pdf']);
    if(r==null||r.files.single.bytes==null)return;
    try{
      final f=r.files.single;
      final raw=f.extension?.toLowerCase()=='pdf'?extractPdfSmart(f.bytes!):utf8.decode(f.bytes!,allowMalformed:true);
      final names=parseSongList(raw);
      if(names.isEmpty)throw Exception('לא נמצאו שמות שירים');
      store.lists.add(Setlist(id:uid(),name:baseName(f.name),names:names));await store.save();
      if(c.mounted)ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text(names.length.toString()+' שירים נוספו לפלייליסט')));
    }catch(e){if(c.mounted)ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text('שגיאה בייבוא: '+e.toString())));}
  }
  Future<void> addPlaylist(BuildContext c)async{
    final t=TextEditingController();
    final n=await showDialog<String>(context:c,builder:(_)=>AlertDialog(title:const Text('פלייליסט חדש'),content:TextField(controller:t,autofocus:true,decoration:const InputDecoration(hintText:'שם הפלייליסט')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('ביטול')),FilledButton(onPressed:()=>Navigator.pop(c,t.text.trim()),child:const Text('צור'))]));
    if(n!=null&&n.isNotEmpty)await store.addPlaylist(n);
  }
  Future<void> addFolder(BuildContext c)async{
    final t=TextEditingController();
    final n=await showDialog<String>(context:c,builder:(_)=>AlertDialog(title:const Text('תיקייה חדשה'),content:TextField(controller:t,autofocus:true),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('ביטול')),FilledButton(onPressed:()=>Navigator.pop(c,t.text.trim()),child:const Text('צור'))]));
    if(n!=null&&n.isNotEmpty)await store.addFolder(n);
  }
  @override Widget build(BuildContext c){
    final rootFolders=store.folders.where((f)=>f.parentId.isEmpty).toList();
    final rootLists=store.lists.where((p)=>p.folderId.isEmpty).toList();
    return Scaffold(appBar:AppBar(title:const Text('פלייליסטים',style:TextStyle(fontWeight:FontWeight.w900)),actions:[IconButton(onPressed:()=>addFolder(c),tooltip:'תיקייה',icon:const Icon(Icons.create_new_folder_outlined)),IconButton(onPressed:()=>importPlaylist(c),tooltip:'ייבוא',icon:const Icon(Icons.upload_file)),IconButton.filledTonal(onPressed:()=>addPlaylist(c),tooltip:'פלייליסט חדש',icon:const Icon(Icons.add))]),body:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('פלייליסטים',style:TextStyle(fontSize:26,fontWeight:FontWeight.w900)),const SizedBox(height:5),const Text('רק שמות השירים — בלי צורך להוסיף אותם לספריית השירים.',style:TextStyle(color:soft)),const SizedBox(height:16),
      ...rootFolders.map((f)=>FolderCard(store:store,folder:f)),...rootLists.map((p)=>PlaylistCard(store:store,playlist:p)),
      if(rootFolders.isEmpty&&rootLists.isEmpty)const Padding(padding:EdgeInsets.all(35),child:Center(child:Text('עדיין אין פלייליסטים. לחץ + כדי ליצור אחד.'))),
    ]));
  }
}
class FolderCard extends StatelessWidget{
  final Store store;final Folder folder;const FolderCard({super.key,required this.store,required this.folder});
  Future<void> act(BuildContext c)async{
    final a=await showModalBottomSheet<String>(context:c,builder:(_)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[ListTile(leading:const Icon(Icons.edit),title:const Text('עריכה'),onTap:()=>Navigator.pop(c,'edit')),ListTile(leading:const Icon(Icons.swap_vert),title:const Text('שינוי מיקום'),onTap:()=>Navigator.pop(c,'move')),ListTile(leading:const Icon(Icons.delete_outline,color:Colors.redAccent),title:const Text('מחיקה'),onTap:()=>Navigator.pop(c,'delete'))])));
    if(a=='edit'&&c.mounted){final t=TextEditingController(text:folder.name);final n=await showDialog<String>(context:c,builder:(_)=>AlertDialog(title:const Text('עריכת תיקייה'),content:TextField(controller:t),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('ביטול')),FilledButton(onPressed:()=>Navigator.pop(c,t.text.trim()),child:const Text('שמור'))]));if(n!=null&&n.isNotEmpty)await store.renameFolder(folder,n);}
    if(a=='move'&&c.mounted){final id=await chooseFolder(c,store,exclude:folder.id);if(id!=null){folder.parentId=id;await store.save();}}
    if(a=='delete'&&c.mounted&&await confirmDelete(c,'למחוק את התיקייה? הפלייליסטים שבתוכה יעברו החוצה.'))await store.deleteFolder(folder);
  }
  @override Widget build(BuildContext c)=>Card(child:InkWell(onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>FolderView(store:store,folder:folder))),onLongPress:()=>act(c),child:ListTile(leading:const Icon(Icons.folder_rounded,color:accent),title:Text(folder.name,style:const TextStyle(fontWeight:FontWeight.w800)),trailing:const Icon(Icons.chevron_left))));
}
class PlaylistCard extends StatelessWidget{
  final Store store;final Setlist playlist;const PlaylistCard({super.key,required this.store,required this.playlist});
  Future<void> act(BuildContext c)async{
    final a=await showModalBottomSheet<String>(context:c,builder:(_)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[ListTile(leading:const Icon(Icons.edit),title:const Text('עריכה'),onTap:()=>Navigator.pop(c,'edit')),ListTile(leading:const Icon(Icons.swap_vert),title:const Text('שינוי מיקום'),onTap:()=>Navigator.pop(c,'move')),ListTile(leading:const Icon(Icons.delete_outline,color:Colors.redAccent),title:const Text('מחיקה'),onTap:()=>Navigator.pop(c,'delete'))])));
    if(a=='edit'&&c.mounted){final t=TextEditingController(text:playlist.name);final n=await showDialog<String>(context:c,builder:(_)=>AlertDialog(title:const Text('עריכת פלייליסט'),content:TextField(controller:t),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('ביטול')),FilledButton(onPressed:()=>Navigator.pop(c,t.text.trim()),child:const Text('שמור'))]));if(n!=null&&n.isNotEmpty)await store.renamePlaylist(playlist,n);}
    if(a=='move'&&c.mounted){final id=await chooseFolder(c,store);if(id!=null)await store.movePlaylist(playlist,id);}
    if(a=='delete'&&c.mounted&&await confirmDelete(c,'למחוק את הפלייליסט?'))await store.deleteList(playlist);
  }
  @override Widget build(BuildContext c)=>Card(child:InkWell(onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>PlaylistView(store:store,playlist:playlist))),onLongPress:()=>act(c),child:ListTile(leading:const Icon(Icons.queue_music_rounded,color:accent),title:Text(playlist.name,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(playlist.names.length.toString()+' שירים'),trailing:const Icon(Icons.chevron_left))));
}
class FolderView extends StatelessWidget{
  final Store store;final Folder folder;const FolderView({super.key,required this.store,required this.folder});
  @override Widget build(BuildContext c){final folders=store.folders.where((x)=>x.parentId==folder.id).toList();final lists=store.lists.where((x)=>x.folderId==folder.id).toList();return Scaffold(appBar:AppBar(title:Text(folder.name)),body:ListView(padding:const EdgeInsets.all(15),children:[...folders.map((f)=>FolderCard(store:store,folder:f)),...lists.map((p)=>PlaylistCard(store:store,playlist:p))]));}
}
class PlaylistView extends StatefulWidget{
  final Store store; final Setlist playlist;
  const PlaylistView({super.key,required this.store,required this.playlist});
  @override State<PlaylistView> createState()=>_PlaylistViewState();
}
class _PlaylistViewState extends State<PlaylistView>{
  @override Widget build(BuildContext c)=>Scaffold(
    appBar:AppBar(title:Text(widget.playlist.name),actions:[IconButton(onPressed:()=>addName(c),icon:const Icon(Icons.add))]),
    body:widget.playlist.names.isEmpty
      ? const Center(child:Text('הפלייליסט ריק. לחץ + כדי להוסיף שם שיר.'))
      : ReorderableListView.builder(
          padding:const EdgeInsets.all(14),itemCount:widget.playlist.names.length,
          onReorder:(oldIndex,newIndex)async{await widget.store.reorderPlaylistNames(widget.playlist,oldIndex,newIndex);if(mounted)setState((){});},
          itemBuilder:(_,i){
            final name=widget.playlist.names[i];
            return ListTile(key:ValueKey(widget.playlist.id+':'+name),leading:CircleAvatar(radius:14,child:Text((i+1).toString())),title:Text(name,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w700)),trailing:const Icon(Icons.drag_handle),onLongPress:()=>nameActions(c,i));
          },
        ),
  );
  Future<void> addName(BuildContext c)async{
    final t=TextEditingController();
    final n=await showDialog<String>(context:c,builder:(_)=>AlertDialog(title:const Text('הוסף שיר לפלייליסט'),content:TextField(controller:t,autofocus:true),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('ביטול')),FilledButton(onPressed:()=>Navigator.pop(c,t.text.trim()),child:const Text('הוסף'))]));
    if(n!=null&&n.isNotEmpty&&!widget.playlist.names.contains(n)){widget.playlist.names=[...widget.playlist.names,n];await widget.store.save();if(mounted)setState((){});}
  }
  Future<void> nameActions(BuildContext c,int i)async{
    final a=await showModalBottomSheet<String>(context:c,builder:(_)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
      ListTile(leading:const Icon(Icons.edit),title:const Text('עריכת שם'),onTap:()=>Navigator.pop(c,'edit')),
      ListTile(leading:const Icon(Icons.swap_vert),title:const Text('שינוי מיקום'),onTap:()=>Navigator.pop(c,'move')),
      ListTile(leading:const Icon(Icons.delete_outline,color:Colors.redAccent),title:const Text('מחיקה'),onTap:()=>Navigator.pop(c,'delete')),
    ])));
    if(a=='edit'&&c.mounted){
      final t=TextEditingController(text:widget.playlist.names[i]);
      final n=await showDialog<String>(context:c,builder:(_)=>AlertDialog(title:const Text('עריכת שם שיר'),content:TextField(controller:t),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('ביטול')),FilledButton(onPressed:()=>Navigator.pop(c,t.text.trim()),child:const Text('שמור'))]));
      if(n!=null&&n.isNotEmpty){final a2=List<String>.from(widget.playlist.names);if(!a2.asMap().entries.any((e)=>e.key!=i&&e.value==n)){a2[i]=n;widget.playlist.names=a2;await widget.store.save();if(mounted)setState((){});}}
    }
    if(a=='delete'){await widget.store.removePlaylistName(widget.playlist,i);if(mounted)setState((){});}
    if(a=='move'&&c.mounted){final pos=await choosePosition(c,i,widget.playlist.names.length);if(pos!=null&&pos!=i){await widget.store.reorderPlaylistNames(widget.playlist,i,pos);if(mounted)setState((){});}}
  }
}
Future<int?> choosePosition(BuildContext c,int current,int count)async=>showModalBottomSheet<int>(context:c,builder:(_)=>SafeArea(child:ListView.builder(shrinkWrap:true,itemCount:count,itemBuilder:(_,i)=>ListTile(leading:Icon(i==current?Icons.radio_button_checked:Icons.radio_button_unchecked),title:Text('מיקום '+(i+1).toString()),onTap:()=>Navigator.pop(c,i)))));
Future<String?> chooseFolder(BuildContext c,Store store,{String exclude=''})async{
  final v=await showModalBottomSheet<String>(context:c,builder:(_)=>SafeArea(child:ListView(children:[const ListTile(title:Text('בחר תיקייה')),ListTile(leading:const Icon(Icons.home_outlined),title:const Text('ללא תיקייה'),onTap:()=>Navigator.pop(c,'')),...store.folders.where((f)=>f.id!=exclude).map((f)=>ListTile(leading:const Icon(Icons.folder_outlined),title:Text(f.name),onTap:()=>Navigator.pop(c,f.id)))])));
  return v;
}

class AddSongs extends StatefulWidget{
  final Store store;final Setlist list;const AddSongs({super.key,required this.store,required this.list});
  @override State<AddSongs> createState()=>_AddSongsState();
}
class _AddSongsState extends State<AddSongs>{
  String q='';
  @override Widget build(BuildContext c){final a=widget.store.songs.where((s)=>!widget.list.ids.contains(s.id)&&(q.isEmpty||s.title.contains(q)||s.style.contains(q))).toList();return Directionality(textDirection:TextDirection.rtl,child:SafeArea(child:Padding(padding:const EdgeInsets.all(16),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Row(children:[const Expanded(child:Text('הוסף שירים',style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),IconButton(onPressed:()=>Navigator.pop(c),icon:const Icon(Icons.close))]),
    TextField(onChanged:(v)=>setState(()=>q=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'חיפוש')),
    const SizedBox(height:10),Flexible(child:ListView.builder(shrinkWrap:true,itemCount:a.length,itemBuilder:(_,i){final s=a[i];return ListTile(title:Text(s.title),subtitle:Text(s.style),trailing:IconButton(onPressed:()async{await widget.store.toggle(widget.list.id,s.id);setState((){});},icon:const Icon(Icons.add_circle_outline)));}))
  ]))));}
}

class Songs extends StatefulWidget{
  final Store store; const Songs({super.key,required this.store});
  @override State<Songs> createState()=>_SongsState();
}
class _SongsState extends State<Songs>{
  String q=''; bool selecting=false; final Set<String> selected={};
  void toggleSelection(String id){setState((){if(selected.contains(id))selected.remove(id);else selected.add(id);if(selected.isEmpty)selecting=false;});}
  void startSelection(String id){setState((){selecting=true;selected.add(id);});}
  void clearSelection()=>setState((){selected.clear();selecting=false;});
  Future<void> bulkDelete(BuildContext c)async{if(selected.isEmpty)return;if(!await confirmDelete(c,'למחוק '+selected.length.toString()+' שירים?'))return;for(final id in Set<String>.from(selected))await widget.store.deleteSong(id);clearSelection();}
  Future<void> bulkMove(BuildContext c)async{if(selected.isEmpty)return;final folder=await chooseFolder(c,widget.store);if(folder==null)return;for(final id in Set<String>.from(selected)){final s=widget.store.song(id);if(s!=null)await widget.store.moveSong(s,folder);}clearSelection();}
  @override Widget build(BuildContext c){
    final a=widget.store.songs.where((s)=>q.isEmpty||s.title.contains(q)||s.artist.contains(q)||s.style.contains(q)).toList();
    return Scaffold(
      appBar:AppBar(
        title:Text(selecting?selected.length.toString()+' נבחרו':'שירים'),
        leading:selecting?IconButton(onPressed:clearSelection,icon:const Icon(Icons.close)):null,
        actions:selecting?[
          IconButton(tooltip:'בחר הכל',onPressed:()=>setState((){selected..clear()..addAll(a.map((s)=>s.id));}),icon:const Icon(Icons.select_all)),
          IconButton(tooltip:'העבר לתיקייה',onPressed:()=>bulkMove(c),icon:const Icon(Icons.drive_file_move_outlined)),
          IconButton(tooltip:'מחק',onPressed:()=>bulkDelete(c),icon:const Icon(Icons.delete_outline)),
        ]:[
          IconButton(tooltip:'בחירה מרובה',onPressed:()=>setState(()=>selecting=true),icon:const Icon(Icons.checklist)),
          IconButton(onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>SmartImport(store:widget.store,mode:'songs'))),icon:const Icon(Icons.folder_copy_outlined)),
          IconButton.filledTonal(onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>Editor(store:widget.store))),icon:const Icon(Icons.add)),
        ],
      ),
      body:Column(children:[
        Padding(padding:const EdgeInsets.all(14),child:TextField(onChanged:(v)=>setState(()=>q=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'חפש שיר, אמן או סגנון'))),
        Expanded(child:ListView.separated(padding:const EdgeInsets.symmetric(horizontal:14),itemCount:a.length,separatorBuilder:(_,__)=>const SizedBox(height:8),itemBuilder:(_,i){
          final song=a[i],isSelected=selected.contains(song.id);
          return SongTile(song:song,selected:isSelected,onLongPress:()=>startSelection(song.id),onTap:()=>selecting?toggleSelection(song.id):Navigator.push(c,MaterialPageRoute(builder:(_)=>Player(store:widget.store,song:song))));
        }))
      ])
    );
  }
}
class SongTile extends StatelessWidget{
  final Song song; final bool selected; final VoidCallback onTap,onLongPress;
  const SongTile({super.key,required this.song,required this.onTap,required this.onLongPress,this.selected=false});
  @override Widget build(BuildContext c)=>Material(color:selected?Theme.of(c).colorScheme.primaryContainer:card,borderRadius:BorderRadius.circular(19),child:InkWell(onTap:onTap,onLongPress:onLongPress,borderRadius:BorderRadius.circular(19),child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[
    selected?Container(width:46,height:46,decoration:BoxDecoration(color:Theme.of(c).colorScheme.primary,borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.check,color:Colors.white)):Container(width:46,height:46,decoration:BoxDecoration(color:accent.withOpacity(.13),borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.music_note,color:accent)),
    const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(song.title,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),const SizedBox(height:4),Text(song.style+' • '+(song.artist.isEmpty?'ללא אמן':song.artist),style:const TextStyle(color:soft,fontSize:12))])),Text(song.key,style:const TextStyle(color:chord,fontWeight:FontWeight.w800))
  ]))));
}
class Player extends StatefulWidget{
  final Store store; final Song song;
  const Player({super.key,required this.store,required this.song});
  @override State<Player> createState()=>_PlayerState();
}
class _PlayerState extends State<Player>{
  int tr=0; double size=19; Timer? timer; final sc=ScrollController();
  @override void dispose(){timer?.cancel();sc.dispose();super.dispose();}
  void play(){
    timer?.cancel();
    timer=Timer.periodic(const Duration(milliseconds:90),(_){
      if(!sc.hasClients)return;
      if(sc.offset>=sc.position.maxScrollExtent){timer?.cancel();setState((){});}
      else sc.jumpTo(math.min(sc.position.maxScrollExtent,sc.offset+1.5));
    });
    setState((){});
  }
  @override Widget build(BuildContext c){
    final sec=parse(widget.song.text); final keys=List.generate(sec.length,(i)=>GlobalKey());
    return Scaffold(
      appBar:AppBar(
        title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(widget.song.title),
          Text(widget.song.style+'  •  '+shift(widget.song.key,tr),style:const TextStyle(fontSize:11,color:soft))
        ]),
        actions:[IconButton(onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>Editor(store:widget.store,song:widget.song))),icon:const Icon(Icons.edit))]
      ),
      body:Column(children:[
        Container(
          margin:const EdgeInsets.all(10),
          padding:const EdgeInsets.symmetric(horizontal:6,vertical:5),
          decoration:BoxDecoration(color:card,borderRadius:BorderRadius.circular(17)),
          child:Row(children:[
            IconButton.filled(onPressed:(){if(timer!=null){timer?.cancel();setState((){});}else{play();}},icon:Icon(timer!=null?Icons.pause:Icons.play_arrow)),
            IconButton(onPressed:()=>setState(()=>tr--),icon:const Icon(Icons.remove)),
            Text(tr==0?'מקורי':(tr>0?'+':'')+tr.toString(),style:const TextStyle(color:chord,fontWeight:FontWeight.bold)),
            IconButton(onPressed:()=>setState(()=>tr++),icon:const Icon(Icons.add)),
            const Icon(Icons.text_fields,size:18,color:soft),
            Expanded(child:Slider(min:16,max:30,value:size,onChanged:(v)=>setState(()=>size=v)))
          ])
        ),
        SizedBox(height:48,child:ListView.separated(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),itemCount:sec.length,separatorBuilder:(_,__)=>const SizedBox(width:6),itemBuilder:(_,i)=>ActionChip(label:Text(sec[i].name),onPressed:()=>Scrollable.ensureVisible(keys[i].currentContext!,duration:const Duration(milliseconds:300),curve:Curves.easeOut)))),
        Expanded(child:ListView.builder(
          controller:sc,padding:const EdgeInsets.fromLTRB(15,5,15,80),
          itemCount:sec.length,
          itemBuilder:(_,i)=>KeyedSubtree(key:keys[i],child:SectionView(section:sec[i],size:size,tr:tr))
        ))
      ])
    );
  }
}

class Section{String name;Color color;List<String> lines;Section(this.name,this.color,this.lines);}
List<Section> parse(String text){final out=<Section>[];String name='שיר';Color color=accent;List<String> lines=[];void flush(){if(lines.isNotEmpty)out.add(Section(name,color,List.of(lines)));lines=[];}for(final raw in text.replaceAll('\r','').split('\n')){final t=raw.trim();if(t.startsWith('#')){flush();name=t.substring(1).trim();color=secColor(name);}else if(t.isNotEmpty)lines.add(raw);}flush();return out;}
Color secColor(String n){final x=n.toLowerCase();if(x.contains('פזמון')||x.contains('chorus'))return const Color(0xFFFF7A59);if(x.contains('מעבר')||x.contains('גשר')||x.contains('bridge'))return const Color(0xFF5EEAD4);if(x.contains('בית')||x.contains('verse'))return const Color(0xFF60A5FA);return const Color(0xFFA78BFA);}

class SectionView extends StatelessWidget{
  final Section section;final double size;final int tr;const SectionView({super.key,required this.section,required this.size,required this.tr});
  @override Widget build(BuildContext c)=>Container(margin:const EdgeInsets.only(bottom:16),padding:const EdgeInsets.fromLTRB(15,12,15,14),decoration:BoxDecoration(color:card,borderRadius:BorderRadius.circular(19),border:Border.all(color:section.color.withOpacity(.3))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Container(width:5,height:22,color:section.color),const SizedBox(width:8),Text(section.name,style:TextStyle(color:section.color,fontWeight:FontWeight.w900))]),const SizedBox(height:10),
    ...section.lines.map((line)=>Padding(padding:const EdgeInsets.only(bottom:10),child:ChordAboveLine(line:line,size:size,tr:tr)))
  ]));
}

class ChordAboveLine extends StatelessWidget{
  final String line;final double size;final int tr;
  const ChordAboveLine({super.key,required this.line,required this.size,required this.tr});
  @override Widget build(BuildContext c){
    final matches=RegExp(r'\[([A-G](?:#|b)?(?:m|maj7|maj|m7|7|sus4|sus|dim|aug|add9|9|11|13)?(?:/[A-G](?:#|b)?)?)\]([^[]*)').allMatches(line).toList();
    if(matches.isEmpty)return Text(line,style:TextStyle(fontSize:size,height:1.55));
    final children=<Widget>[];
    var last=0;
    for(final m in matches){
      if(m.start>last){children.add(Text(line.substring(last,m.start),style:TextStyle(fontSize:size,height:1.55)));}
      final text=m.group(2)!;
      children.add(Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text(shift(m.group(1)!,tr),style:TextStyle(color:chord,fontWeight:FontWeight.w900,fontSize:size*.72,height:1.0)),
        Text(text,style:TextStyle(fontSize:size,height:1.35)),
      ]));
      last=m.end;
    }
    if(last<line.length)children.add(Text(line.substring(last),style:TextStyle(fontSize:size,height:1.55)));
    return Wrap(textDirection:TextDirection.rtl,crossAxisAlignment:WrapCrossAlignment.end,spacing:2,runSpacing:0,children:children);
  }
}
final chordRx=RegExp(r'\[([A-G](?:#|b)?(?:m|maj7|maj|m7|7|sus4|sus|dim|aug|add9|9|11|13)?(?:/[A-G](?:#|b)?)?)\]|(?<![A-Za-z])([A-G](?:#|b)?(?:m|maj7|maj|m7|7|sus4|sus|dim|aug|add9|9|11|13)?(?:/[A-G](?:#|b)?)?)(?![A-Za-z])');
List<(String,bool)> parts(String s){final a=<(String,bool)>[];int last=0;for(final m in chordRx.allMatches(s)){if(m.start>last)a.add((s.substring(last,m.start),false));a.add(((m.group(1)??m.group(2)??''),true));last=m.end;}if(last<s.length)a.add((s.substring(last),false));if(a.isEmpty)a.add((s,false));return a;}
bool isChord(String s)=>RegExp(r'^[A-G](?:#|b)?(?:m|maj7|maj|m7|7|sus4|sus|dim|aug|add9|9|11|13)?(?:/[A-G](?:#|b)?)?$').hasMatch(s);
String normalize(String input){final l=input.replaceAll('\r','').split('\n');final out=<String>[];for(int i=0;i<l.length;i++){final t=l[i].trimRight();if(t.trim().isEmpty){out.add('');continue;}if(t.trim().startsWith('#')){out.add('# '+t.trim().replaceFirst(RegExp(r'^#+\s*'),''));continue;}final tok=t.trim().split(RegExp(r'\s+'));if(tok.isNotEmpty&&tok.every(isChord)){out.add(tok.map((x)=>'['+x+']').join(' '));continue;}final h=heading(t.trim());if(h!=null&&t.trim().length<25){out.add('# '+h);}else out.add(t);}return out.join('\n');}
String? heading(String s){final x=s.toLowerCase();if(x=='בית'||x=='verse'||x=='verse 1')return'בית';if(x=='פזמון'||x=='chorus')return'פזמון';if(x=='מעבר'||x=='גשר'||x=='bridge')return'מעבר';if(x=='פתיחה'||x=='intro')return'פתיחה';if(x=='סיום'||x=='outro')return'סיום';return null;}
const notes=['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];
String shift(String raw,int n){final m=RegExp(r'^([A-G](?:#|b)?)(.*)$').firstMatch(raw);if(m==null)return raw;var root=m.group(1)!;root=root.replaceAll('Db','C#').replaceAll('Eb','D#').replaceAll('Gb','F#').replaceAll('Ab','G#').replaceAll('Bb','A#');final i=notes.indexOf(root);if(i<0)return raw;final x=(i+n)%12;final j=x<0?x+12:x;return notes[j]+m.group(2)!;}

class Editor extends StatefulWidget{
  final Store store;final Song? song;const Editor({super.key,required this.store,this.song});@override State<Editor> createState()=>_EditorState();
}
class _EditorState extends State<Editor>{
  late TextEditingController title,artist,style,key,body;String? listId;
  @override void initState(){super.initState();final s=widget.song;title=TextEditingController(text:s?.title??'');artist=TextEditingController(text:s?.artist??'');style=TextEditingController(text:s?.style??'כללי');key=TextEditingController(text:s?.key??'C');body=TextEditingController(text:s?.text??'# בית\n');listId=widget.store.lists.isEmpty?null:widget.store.lists.first.id;}
  @override void dispose(){title.dispose();artist.dispose();style.dispose();key.dispose();body.dispose();super.dispose();}
  Future<void> importFile()async{final r=await FilePicker.platform.pickFiles(withData:true,type:FileType.custom,allowedExtensions:['txt','pdf']);if(r==null||r.files.single.bytes==null)return;try{final f=r.files.single;final t=await smartExtractFile(f.path,f.bytes!,f.extension??'');body.text=normalize(t);if(title.text.trim().isEmpty)title.text=f.name.replaceAll(RegExp(r'\.(txt|pdf)$',caseSensitive:false),'');setState((){});}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('שגיאה בייבוא: '+e.toString())));}}
  Future<void> save()async{if(title.text.trim().isEmpty)return;final s=widget.song??Song(id:uid(),title:title.text.trim());s.title=title.text.trim();s.artist=artist.text.trim();s.style=style.text.trim().isEmpty?'כללי':style.text.trim();s.key=key.text.trim().isEmpty?'C':key.text.trim();s.text=normalize(body.text);await widget.store.putSong(s);if(widget.song==null&&listId!=null)await widget.store.toggle(listId!,s.id);if(mounted)Navigator.pop(context);}
  @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text(widget.song==null?'שיר חדש':'עריכת שיר'),actions:[IconButton(onPressed:importFile,icon:const Icon(Icons.upload_file)),IconButton(onPressed:save,icon:const Icon(Icons.check))]),body:ListView(padding:const EdgeInsets.all(15),children:[
    TextField(controller:title,style:const TextStyle(fontSize:23,fontWeight:FontWeight.bold),decoration:const InputDecoration(hintText:'שם השיר')),
    const SizedBox(height:10),Row(children:[Expanded(child:TextField(controller:artist,decoration:const InputDecoration(labelText:'אמן'))),const SizedBox(width:8),Expanded(child:TextField(controller:style,decoration:const InputDecoration(labelText:'סגנון')))]),
    const SizedBox(height:8),Row(children:[Expanded(child:TextField(controller:key,decoration:const InputDecoration(labelText:'סולם'))),const SizedBox(width:8),if(widget.song==null&&widget.store.lists.isNotEmpty)Expanded(child:DropdownButtonFormField<String>(initialValue:listId,decoration:const InputDecoration(labelText:'רשימת הופעה'),items:widget.store.lists.map((x)=>DropdownMenuItem(value:x.id,child:Text(x.name,overflow:TextOverflow.ellipsis))).toList(),onChanged:(v)=>setState(()=>listId=v)))]),
    const SizedBox(height:14),const Text('תוכן השיר',style:TextStyle(fontWeight:FontWeight.bold)),const SizedBox(height:5),const Text('אפשר להדביק [Am]מילים, או שורות אקורדים כמו Am F C G. המערכת מזהה אותיות באנגלית כאקורדים.',style:TextStyle(color:soft,fontSize:12)),
    const SizedBox(height:8),TextField(controller:body,minLines:20,maxLines:35,style:const TextStyle(height:1.55),decoration:const InputDecoration(hintText:'# בית\n[Am]מילים כאן...\n\n# פזמון\n[C]הפזמון...')),
    const SizedBox(height:12),FilledButton.tonalIcon(onPressed:importFile,icon:const Icon(Icons.upload_file),label:const Text('ייבוא TXT / PDF')),const SizedBox(height:8),FilledButton.icon(onPressed:save,icon:const Icon(Icons.save),label:const Text('שמור שיר'))
  ]));
}



String extractPdfSmart(List<int> bytes){
  final d=PdfDocument(inputBytes:bytes);
  try{
    final lines=PdfTextExtractor(d).extractTextLines();if(lines.isEmpty)return '';
    final pages=<int,List<TextLine>>{};for(final l in lines){pages.putIfAbsent(l.pageIndex,()=>[]).add(l);}
    final out=<String>[];
    for(final page in pages.keys.toList()..sort()){
      final ls=pages[page]!..sort((x,y)=>x.bounds.top.compareTo(y.bounds.top));
      for(int i=0;i<ls.length;i++){
        final line=ls[i],words=[...line.wordCollection],heb=containsHebrew(line.text);
        words.sort((x,y)=>heb?y.bounds.left.compareTo(x.bounds.left):x.bounds.left.compareTo(y.bounds.left));
        final text=words.map((w)=>w.text).join(' ').trim();if(text.isEmpty)continue;
        if(looksLikeChordLine(text)&&i+1<ls.length){
          final below=ls[i+1],bw=[...below.wordCollection],bheb=containsHebrew(below.text);
          bw.sort((x,y)=>bheb?y.bounds.left.compareTo(x.bounds.left):x.bounds.left.compareTo(y.bounds.left));
          if(bw.isNotEmpty&&!looksLikeChordLine(below.text)&&below.bounds.top-line.bounds.bottom<line.fontSize*3){out.add(attachChords(words,bw,bheb));i++;continue;}
        }
        out.add(text);
      }
      out.add('');
    }
    return normalize(out.join('\n'));
  }finally{d.dispose();}
}
bool containsHebrew(String s)=>RegExp(r'[\u0590-\u05FF]').hasMatch(s);
bool looksLikeChordLine(String s){
 final t=s.replaceAll(RegExp(r'[|,;]'),' ').split(RegExp(r'\\s+')).where((x)=>x.isNotEmpty).toList();
 if(t.isEmpty||t.length>18)return false;
 final n=t.where((x)=>isChord(x.replaceAll(RegExp(r'x\\d+$'),''))).length;
 return n/t.length>=.65;
}
Future<String> smartExtractFile(String? path,List<int> bytes,String extension)async{
 final e=extension.toLowerCase();
 if(e=='txt')return normalize(utf8.decode(bytes,allowMalformed:true));
 if(e=='pdf'){final d=PdfDocument(inputBytes:bytes);try{return normalize(PdfTextExtractor(d).extractText());}finally{d.dispose();}}
 final dir=await getTemporaryDirectory();
 final f=File(dir.path+'/bama_ocr_'+DateTime.now().microsecondsSinceEpoch.toString()+'.'+e);
 await f.writeAsBytes(bytes,flush:true);
 try{return normalize(await FlutterTesseractOcr.extractText(f.path,language:'heb+eng',args:{'psm':'6'}));}finally{if(await f.exists())await f.delete();}
}
List<String> parseSongList(String raw){final out=<String>[];for(final line in raw.replaceAll('\r','').split('\n')){var x=line.trim();if(x.isEmpty)continue;x=x.replaceFirst(RegExp(r'^\s*(?:\d+[.)\-:]|[-•])\s*'),'');if(isChord(x)||looksLikeChordLine(x)||x.length>90)continue;if(RegExp(r'^(רשימת שירים|שירים|playlist|setlist)$',caseSensitive:false).hasMatch(x))continue;if(!out.contains(x))out.add(x);}return out;}
String baseName(String path)=>path.split(Platform.pathSeparator).last.replaceFirst(RegExp(r'\.(txt|pdf|jpg|jpeg|png|webp|bmp)$',caseSensitive:false),'');
String inferStyle(String path,List<String> styles){final p=path.toLowerCase();for(final s in styles){if(s!='כללי'&&p.contains(s.toLowerCase()))return s;}return 'כללי';}

class SmartImport extends StatefulWidget{
  final Store store;final String mode;
  const SmartImport({super.key,required this.store,required this.mode});
  @override State<SmartImport> createState()=>_SmartImportState();
}
class _SmartImportState extends State<SmartImport>{
  bool busy=false;String status='';
  Future<void> scan()async{
    final files=await FilePicker.platform.pickFiles(allowMultiple:true,withData:true,type:FileType.custom,allowedExtensions:['txt','pdf','jpg','jpeg','png','webp','bmp']);if(files==null)return;
    setState((){busy=true;status='מפעיל סריקה חכמה...';});
    try{
      int count=0;
      for(final f in files.files){if(f.bytes==null)continue;final text=await smartExtractFile(f.path,f.bytes!,f.extension??''),title=baseName(f.name);
        if(widget.mode=='lists'){final names=parseSongList(text);if(names.isNotEmpty)widget.store.lists.add(Setlist(id:uid(),name:title,names:names));}
        else{final existing=widget.store.songs.where((x)=>x.title.trim()==title.trim()).cast<Song?>().firstOrNull;if(existing==null)widget.store.songs.add(Song(id:uid(),title:title,style:inferStyle(f.name,widget.store.styles),text:text));else if(existing.text.trim().isEmpty)existing.text=text;}
        count++;if(mounted)setState(()=>status='טופל: '+count.toString()+' / '+files.files.length.toString());
      }
      await widget.store.save();if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('הסריקה הסתיימה: '+count.toString()+' קבצים')));
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('שגיאה בסריקה: '+e.toString())));}
    finally{if(mounted)setState(()=>busy=false);}
  }
  @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:Text(widget.mode=='lists'?'סריקת רשימות':'סריקה חכמה')),body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
    const LogoMark(size:82),const SizedBox(height:18),Text(widget.mode=='lists'?'סריקת רשימות שירים':'סריקה חכמה של שירים',style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900),textAlign:TextAlign.center),const SizedBox(height:8),const Text('PDF • TXT • תמונות\nזיהוי OCR, אקורדים, מילים ומבנה שיר',style:TextStyle(color:soft),textAlign:TextAlign.center),const SizedBox(height:22),if(busy)const CircularProgressIndicator() else FilledButton.icon(onPressed:scan,icon:const Icon(Icons.document_scanner_outlined),label:const Text('בחר קבצים')),if(status.isNotEmpty)Padding(padding:const EdgeInsets.only(top:16),child:Text(status,style:const TextStyle(color:soft)))
  ]))));
}
class SettingsPage extends StatelessWidget{
  final Store store;const SettingsPage({super.key,required this.store});
  @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('הגדרות',style:TextStyle(fontWeight:FontWeight.w900))),body:ListView(padding:const EdgeInsets.all(15),children:[
    const Text('התאמה אישית',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800)),const SizedBox(height:7),
    Card(child:Column(children:[
      ListTile(leading:const Icon(Icons.palette_outlined),title:const Text('ערכת נושא'),subtitle:Text(themeName(store.theme)),onTap:()=>showThemePicker(c,store)),
      const Divider(height:1),
      ListTile(leading:const Icon(Icons.style_outlined),title:const Text('סגנונות'),subtitle:Text(store.styles.length.toString()+' סגנונות'),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>StylesPage(store:store)))),
    ])),
    const SizedBox(height:18),const Text('סריקה חכמה',style:TextStyle(fontSize:21,fontWeight:FontWeight.w800)),const SizedBox(height:7),
    Card(child:Column(children:[
      ListTile(leading:const Icon(Icons.folder_special_outlined),title:const Text('סריקת תיקיית שירים'),subtitle:const Text('מוסיף TXT/PDF מתיקיות משנה כשירים'),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>SmartImport(store:store,mode:'songs')))),
      const Divider(height:1),
      ListTile(leading:const Icon(Icons.playlist_add_check),title:const Text('סריקת תיקיית רשימות'),subtitle:const Text('כל קובץ הופך לרשימת שירים'),onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>SmartImport(store:store,mode:'lists')))),
    ])),
    const SizedBox(height:18),
    Card(child:Padding(padding:const EdgeInsets.all(17),child:Row(children:[const LogoMark(size:52),const SizedBox(width:12),const Expanded(child:Text('לוגו חדש: אקולייזר שמייצג במה, מוזיקה ושליטה בהופעה.'))]))),
  ]));
}
Future<void> showThemePicker(BuildContext c,Store store)async{
  final v=await showModalBottomSheet<int>(context:c,builder:(_)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
    for(int i=0;i<5;i++)ListTile(leading:Icon(i==store.theme?Icons.radio_button_checked:Icons.radio_button_off),title:Text(themeName(i)),onTap:()=>Navigator.pop(c,i))
  ])));
  if(v!=null)await store.setTheme(v);
}
class StylesPage extends StatelessWidget{
  final Store store;const StylesPage({super.key,required this.store});
  Future<void> add(BuildContext c)async{
    final t=TextEditingController();
    final n=await showDialog<String>(context:c,builder:(_)=>AlertDialog(title:const Text('סגנון חדש'),content:TextField(controller:t,autofocus:true),actions:[
      TextButton(onPressed:()=>Navigator.pop(c),child:const Text('ביטול')),
      FilledButton(onPressed:()=>Navigator.pop(c,t.text.trim()),child:const Text('הוסף'))
    ]));
    if(n!=null)await store.addStyle(n);
  }
  @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('סגנונות'),actions:[IconButton(onPressed:()=>add(c),icon:const Icon(Icons.add))]),body:ListView(padding:const EdgeInsets.all(15),children:[
    const Text('אפשר להוסיף ולמחוק סגנונות. הם משמשים לסינון בתוך רשימות.',style:TextStyle(color:soft)),const SizedBox(height:10),
    ...store.styles.map((x)=>Card(child:ListTile(leading:const Icon(Icons.label_outline,color:accent),title:Text(x),trailing:IconButton(onPressed:()async{
      if(await confirmDelete(c,'למחוק את הסגנון? השירים יעברו ל״כללי״.'))await store.deleteStyle(x);
    },icon:const Icon(Icons.delete_outline)))))
  ]));
}
Future<bool> confirmDelete(BuildContext c,String text)async{
  final r=await showDialog<bool>(context:c,builder:(_)=>AlertDialog(title:const Text('אישור מחיקה'),content:Text(text),actions:[
    TextButton(onPressed:()=>Navigator.pop(c,false),child:const Text('ביטול')),
    FilledButton(onPressed:()=>Navigator.pop(c,true),child:const Text('מחק'))
  ]));
  return r==true;
}

class Info extends StatelessWidget{final Store store;const Info({super.key,required this.store});@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('מידע')),body:ListView(padding:const EdgeInsets.all(16),children:[
  Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:card,borderRadius:BorderRadius.circular(24)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('במה',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900)),const SizedBox(height:5),const Text('הופעות מסודרות. שירים מוכנים. אקורדים ברורים.',style:TextStyle(color:soft)),const SizedBox(height:18),Text(store.lists.length.toString()+' רשימות  •  '+store.songs.length.toString()+' שירים',style:const TextStyle(fontWeight:FontWeight.bold))])),
  const SizedBox(height:12),const ListTile(leading:Icon(Icons.style),title:Text('חלוקה לפי סגנון'),subtitle:Text('בתוך כל רשימת הופעה יש מעבר מהיר בין סגנונות.')),
  const ListTile(leading:Icon(Icons.text_fields),title:Text('זיהוי אקורדים'),subtitle:Text('C, Am, Dm7, G/B ועוד מזוהים אוטומטית.')),
  const ListTile(leading:Icon(Icons.picture_as_pdf),title:Text('TXT ו-PDF'),subtitle:Text('ייבוא קובץ והפיכתו לשיר מסודר. PDF סרוק כתמונה דורש OCR.')),
]));}