import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

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
  @override Widget build(BuildContext c)=>MaterialApp(
    debugShowCheckedModeBanner:false,title:'במה',
    theme:appTheme(store.theme),
    home:Directionality(textDirection:TextDirection.rtl,child:Home(store:store)),
  );
}

class Song {
  String id,title,artist,style,key,text;
  Song({required this.id,required this.title,this.artist='',this.style='כללי',this.key='C',this.text=''});
  Map<String,dynamic> toJson()=>{'id':id,'title':title,'artist':artist,'style':style,'key':key,'text':text};
  factory Song.fromJson(Map<String,dynamic> j)=>Song(id:j['id']??uid(),title:j['title']??'שיר',artist:j['artist']??'',style:j['style']??'כללי',key:j['key']??'C',text:j['text']??'');
}
class Setlist {
  String id,name; List<String> ids;
  Setlist({required this.id,required this.name,this.ids=const[]});
  Map<String,dynamic> toJson()=>{'id':id,'name':name,'ids':ids};
  factory Setlist.fromJson(Map<String,dynamic> j)=>Setlist(id:j['id']??uid(),name:j['name']??'רשימה',ids:List<String>.from(j['ids']??[]));
}
String uid()=>DateTime.now().microsecondsSinceEpoch.toString()+math.Random().nextInt(999).toString();

class Store extends ChangeNotifier {
  List<Song> songs=[]; List<Setlist> lists=[]; List<String> styles=['חסידי','שקט','קצבי','מזרחי','כללי']; int theme=0;
  Future<void> load() async {
    final p=await SharedPreferences.getInstance(), raw=p.getString('bama_v3');
    if(raw==null){ songs=demo(); lists=[Setlist(id:uid(),name:'הופעה – יום שישי',ids:songs.map((x)=>x.id).toList()),Setlist(id:uid(),name:'חזרות',ids:songs.take(2).map((x)=>x.id).toList())]; await save(); }
    else { final j=jsonDecode(raw); songs=(j['songs'] as List? ?? []).map((x)=>Song.fromJson(x)).toList(); lists=(j['lists'] as List? ?? []).map((x)=>Setlist.fromJson(x)).toList(); styles=List<String>.from(j['styles']??styles); theme=j['theme']??0; }
  }
  Future<void> save() async { final p=await SharedPreferences.getInstance(); await p.setString('bama_v3',jsonEncode({'songs':songs.map((x)=>x.toJson()).toList(),'lists':lists.map((x)=>x.toJson()).toList(),'styles':styles,'theme':theme})); notifyListeners(); }
  Song? song(String id){for(final s in songs){if(s.id==id)return s;}return null;}
  Future<void> putSong(Song s) async { final i=songs.indexWhere((x)=>x.id==s.id); if(i<0)songs.add(s);else songs[i]=s; if(!styles.contains(s.style))styles.add(s.style); await save(); }
Future<void> deleteSong(String id) async {songs.removeWhere((s)=>s.id==id);for(final l in lists){l.ids.remove(id);}await save();}
Future<void> renameList(Setlist l,String n) async {l.name=n;await save();}
Future<void> deleteList(Setlist l) async {lists.removeWhere((x)=>x.id==l.id);await save();}
Future<void> addStyle(String s) async {s=s.trim();if(s.isNotEmpty&&!styles.contains(s)){styles.add(s);await save();}}
Future<void> deleteStyle(String s) async {if(styles.length<=1)return;styles.remove(s);for(final x in songs){if(x.style==s)x.style='כללי';}await save();}
Future<void> setTheme(int t) async {theme=t;await save();}
  Future<void> addList(String n) async {lists.add(Setlist(id:uid(),name:n));await save();}
  Future<void> toggle(String lid,String sid) async {final l=lists.firstWhere((x)=>x.id==lid);if(l.ids.contains(sid))l.ids.remove(sid);else l.ids.add(sid);await save();}
}
List<Song> demo()=>[
 Song(id:uid(),title:'רגעים',artist:'הדגמה',style:'חסידי',key:'Am',text:'# בית\n[Am]זה הבית הראשון\n[F]שרים ביחד\n\n# פזמון\n[C]כולם שרים עכשיו\n[G]והלב עולה\n\n# מעבר\n[Dm]עוברים בשקט\n[E]וחוזרים'),
 Song(id:uid(),title:'עוד יום',artist:'הדגמה',style:'שקט',key:'C',text:'# בית\nC              Am\nעוד יום מתחיל כאן\nF              G\nואנחנו ממשיכים\n\n# פזמון\n[C]עוד יום עוד אור\n[Am]עוד סיבה לשיר'),
 Song(id:uid(),title:'קצב הלילה',style:'קצבי',key:'G',text:'# בית\nG D Em C\nהלילה מתחיל עכשיו\n\n# פזמון\n[G]בואו נרים את הקצב\n[D]ונשיר ביחד'),
];

class Home extends StatefulWidget {
  final Store store; const Home({super.key,required this.store});
  @override State<Home> createState()=>_HomeState();
}
class _HomeState extends State<Home>{
  int tab=0;
  @override Widget build(BuildContext c)=>AnimatedBuilder(animation:widget.store,builder:(_,__)=>Scaffold(
    body:SafeArea(child:IndexedStack(index:tab,children:[Lists(store:widget.store),Lists(store:widget.store),Songs(store:widget.store),SettingsPage(store:widget.store)])),
    bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(v)=>setState(()=>tab=v),destinations:const[
      NavigationDestination(icon:Icon(Icons.dashboard_outlined),selectedIcon:Icon(Icons.dashboard),label:'הופעות'),
      NavigationDestination(icon:Icon(Icons.view_list_outlined),selectedIcon:Icon(Icons.view_list),label:'רשימות'),
      NavigationDestination(icon:Icon(Icons.library_music_outlined),selectedIcon:Icon(Icons.library_music),label:'שירים'),
      NavigationDestination(icon:Icon(Icons.settings_outlined),selectedIcon:Icon(Icons.settings),label:'הגדרות'),
    ]),
  ));
}

class Lists extends StatelessWidget{
  final Store store; const Lists({super.key,required this.store});
  Future<void> importListFile(BuildContext c)async{final r=await FilePicker.platform.pickFiles(withData:true,type:FileType.custom,allowedExtensions:['txt','pdf']);if(r==null||r.files.single.bytes==null)return;try{final f=r.files.single;final raw=f.extension?.toLowerCase()=='pdf'?extractPdfSmart(f.bytes!):utf8.decode(f.bytes!,allowMalformed:true);final names=parseSongList(raw);if(names.isEmpty)throw Exception('לא נמצאו שמות שירים');await store.addList(baseName(f.name));final l=store.lists.last;for(final n in names){final e=store.songs.where((x)=>x.title.trim()==n.trim()).cast<Song?>().firstOrNull;final song=e??Song(id:uid(),title:n);if(e==null)store.songs.add(song);l.ids.add(song.id);}await store.save();if(c.mounted)ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text('${names.length} שירים נוספו לרשימה')));}catch(e){if(c.mounted)ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text('שגיאה בייבוא: $e')));}}
  Future<void> add(BuildContext c)async{final t=TextEditingController();final n=await showDialog<String>(context:c,builder:(_)=>AlertDialog(title:const Text('רשימת הופעה חדשה'),content:TextField(controller:t,autofocus:true,decoration:const InputDecoration(hintText:'שם ההופעה')),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('ביטול')),FilledButton(onPressed:()=>Navigator.pop(c,t.text.trim()),child:const Text('צור'))]));if(n!=null&&n.isNotEmpty)await store.addList(n);}
  @override Widget build(BuildContext c)=>Scaffold(
    appBar:AppBar(title:const Text('רשימות שירים',style:TextStyle(fontWeight:FontWeight.w900)),actions:[IconButton(onPressed:()=>importListFile(c),icon:const Icon(Icons.upload_file)),IconButton.filledTonal(onPressed:()=>add(c),icon:const Icon(Icons.add))]),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('רשימות ההופעה שלך',style:TextStyle(fontSize:25,fontWeight:FontWeight.w800)),
      const SizedBox(height:5),const Text('חלק כל רשימה לפי סגנון ועבור ביניהם במהירות.',style:TextStyle(color:soft)),const SizedBox(height:18),
      ...store.lists.map((l)=>ListCard(store:store,list:l)),
        Container(width:54,height:54,decoration:BoxDecoration(color:accent.withOpacity(.15),borderRadius:BorderRadius.circular(17)),child:const Icon(Icons.mic_external_on,color:accent)),
        const SizedBox(width:14),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(l.name,style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),const SizedBox(height:5),Text(l.ids.length.toString()+' שירים',style:const TextStyle(color:soft))])),
        const Icon(Icons.chevron_left,color:soft)
      ])))))),
    ]),
  );
}

class ListCard extends StatelessWidget{
  final Store store; final Setlist list;
  const ListCard({super.key,required this.store,required this.list});
  Future<void> act(BuildContext c)async{
    final a=await showModalBottomSheet<String>(context:c,builder:(_)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
      ListTile(leading:const Icon(Icons.edit),title:const Text('עריכת שם'),onTap:()=>Navigator.pop(c,'edit')),
      ListTile(leading:const Icon(Icons.delete_outline,color:Colors.redAccent),title:const Text('מחיקה'),onTap:()=>Navigator.pop(c,'delete')),
    ])));
    if(a=='edit'){final t=TextEditingController(text:list.name);final n=await showDialog<String>(context:c,builder:(_)=>AlertDialog(title:const Text('עריכת רשימה'),content:TextField(controller:t),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('ביטול')),FilledButton(onPressed:()=>Navigator.pop(c,t.text.trim()),child:const Text('שמור'))]));if(n!=null&&n.isNotEmpty)await store.renameList(list,n);}
    if(a=='delete'&&c.mounted&&await confirmDelete(c,'למחוק את הרשימה?'))await store.deleteList(list);
  }
  @override Widget build(BuildContext c)=>Card(child:InkWell(onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>SetlistView(store:store,list:list))),onLongPress:()=>act(c),child:Padding(padding:const EdgeInsets.all(15),child:Row(children:[
    const CircleAvatar(backgroundColor:Color(0x223F51B5),child:Icon(Icons.list_alt,color:accent)),const SizedBox(width:13),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(list.name,style:const TextStyle(fontWeight:FontWeight.w800,fontSize:17)),const SizedBox(height:4),Text('${list.ids.length} שירים • לחיצה ארוכה לעריכה/מחיקה',style:const TextStyle(color:soft,fontSize:12))])),
    const Icon(Icons.chevron_left,color:soft),
  ]))));
}

class SetlistView extends StatefulWidget{
  final Store store; final Setlist list;
  const SetlistView({super.key,required this.store,required this.list});
  @override State<SetlistView> createState()=>_SetlistViewState();
}
class _SetlistViewState extends State<SetlistView>{
  String style='הכל';
  @override Widget build(BuildContext c){
    final all=widget.list.ids.map(widget.store.song).whereType<Song>().toList();
    final styles=['הכל',...all.map((x)=>x.style).toSet()];
    final shown=all.where((x)=>style=='הכל'||x.style==style).toList();
    return Scaffold(
      appBar:AppBar(title:Text(widget.list.name),actions:[
        IconButton(onPressed:()=>showModalBottomSheet(context:c,isScrollControlled:true,builder:(_)=>AddSongs(store:widget.store,list:widget.list)),icon:const Icon(Icons.playlist_add))
      ]),
      floatingActionButton:FloatingActionButton.extended(
        onPressed:()=>showModalBottomSheet(context:c,isScrollControlled:true,builder:(_)=>AddSongs(store:widget.store,list:widget.list)),
        icon:const Icon(Icons.add),label:const Text('הוסף')),
      body:Column(children:[
        SizedBox(height:60,child:ListView.separated(
          scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:14,vertical:9),
          itemCount:styles.length,separatorBuilder:(_,__)=>const SizedBox(width:7),
          itemBuilder:(_,i)=>ChoiceChip(label:Text(styles[i]),selected:style==styles[i],onSelected:(_)=>setState(()=>style=styles[i]))
        )),
        Expanded(child:ListView.separated(
          padding:const EdgeInsets.fromLTRB(14,5,14,90),itemCount:shown.length,separatorBuilder:(_,__)=>const SizedBox(height:9),
          itemBuilder:(_,i){
            final song=shown[i];
            return LongSongTile(store:widget.store,song:song);
          }
        ))
      ])
    );
  }
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
  final Store store;
  const Songs({super.key,required this.store});
  @override State<Songs> createState()=>_SongsState();
}
class _SongsState extends State<Songs>{
  String q='';
  @override Widget build(BuildContext c){
    final a=widget.store.songs.where((s)=>q.isEmpty||s.title.contains(q)||s.artist.contains(q)||s.style.contains(q)).toList();
    return Scaffold(
      appBar:AppBar(title:const Text('שירים'),actions:[IconButton(onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>SmartImport(store:widget.store,mode:'songs'))),icon:const Icon(Icons.folder_copy_outlined)),IconButton.filledTonal(onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>Editor(store:widget.store))),icon:const Icon(Icons.add))]),
      body:Column(children:[
        Padding(padding:const EdgeInsets.all(14),child:TextField(onChanged:(v)=>setState(()=>q=v),decoration:const InputDecoration(prefixIcon:Icon(Icons.search),hintText:'חפש שיר, אמן או סגנון'))),
        Expanded(child:ListView.separated(
          padding:const EdgeInsets.symmetric(horizontal:14),
          itemCount:a.length,
          separatorBuilder:(_,__)=>const SizedBox(height:8),
          itemBuilder:(_,i){
            final song=a[i];
            return SongTile(song:song,onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>Player(store:widget.store,song:song))));
          }
        ))
      ])
    );
  }
}

class SongTile extends StatelessWidget{
  final Song song;final VoidCallback onTap;const SongTile({super.key,required this.song,required this.onTap});
  @override Widget build(BuildContext c)=>Material(color:card,borderRadius:BorderRadius.circular(19),child:InkWell(onTap:onTap,borderRadius:BorderRadius.circular(19),child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[
    Container(width:46,height:46,decoration:BoxDecoration(color:accent.withOpacity(.13),borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.music_note,color:accent)),
    const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(song.title,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),const SizedBox(height:4),Text(song.style+'  •  '+(song.artist.isEmpty?'ללא אמן':song.artist),style:const TextStyle(color:soft,fontSize:12))])),
    Text(song.key,style:const TextStyle(color:chord,fontWeight:FontWeight.w800))
  ]))));
}

class LongSongTile extends StatelessWidget{
  final Store store;final Song song;const LongSongTile({super.key,required this.store,required this.song});
  Future<void> act(BuildContext c)async{final a=await showModalBottomSheet<String>(context:c,builder:(_)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[ListTile(leading:const Icon(Icons.edit),title:const Text('עריכה'),onTap:()=>Navigator.pop(c,'edit')),ListTile(leading:const Icon(Icons.delete_outline,color:Colors.redAccent),title:const Text('מחיקה'),onTap:()=>Navigator.pop(c,'delete'))])));if(a=='edit'&&c.mounted)Navigator.push(c,MaterialPageRoute(builder:(_)=>Editor(store:store,song:song)));if(a=='delete'&&c.mounted&&await confirmDelete(c,'למחוק את השיר?'))await store.deleteSong(song.id);}
  @override Widget build(BuildContext c)=>Material(color:card,borderRadius:BorderRadius.circular(19),child:InkWell(onTap:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>Player(store:store,song:song))),onLongPress:()=>act(c),borderRadius:BorderRadius.circular(19),child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[Container(width:46,height:46,decoration:BoxDecoration(color:accent.withOpacity(.13),borderRadius:BorderRadius.circular(14)),child:const Icon(Icons.music_note,color:accent)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(song.title,style:const TextStyle(fontWeight:FontWeight.bold,fontSize:16)),const SizedBox(height:4),Text(song.style+' • '+(song.artist.isEmpty?'ללא אמן':song.artist),style:const TextStyle(color:soft,fontSize:12))])),Text(song.key,style:const TextStyle(color:chord,fontWeight:FontWeight.w800))]))));
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
    ...section.lines.map((line)=>Padding(padding:const EdgeInsets.only(bottom:7),child:Wrap(crossAxisAlignment:WrapCrossAlignment.end,children:parts(line).map((p)=>p.$2?Padding(padding:const EdgeInsets.symmetric(horizontal:2),child:Text(shift(p.$1,tr),style:TextStyle(color:chord,fontWeight:FontWeight.w900,fontSize:size*.72))):Text(p.$1,style:TextStyle(fontSize:size,height:1.55))).toList())))
  ]));
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
  Future<void> importFile()async{final r=await FilePicker.platform.pickFiles(withData:true,type:FileType.custom,allowedExtensions:['txt','pdf']);if(r==null||r.files.single.bytes==null)return;try{final f=r.files.single;String t;if(f.extension?.toLowerCase()=='pdf'){final d=PdfDocument(inputBytes:f.bytes!);t=PdfTextExtractor(d).extractText();d.dispose();}else{t=utf8.decode(f.bytes!,allowMalformed:true);}body.text=normalize(t);if(title.text.trim().isEmpty)title.text=f.name.replaceAll(RegExp(r'\.(txt|pdf)$',caseSensitive:false),'');setState((){});}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('שגיאה בייבוא: '+e.toString())));}}
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

class Info extends StatelessWidget{final Store store;const Info({super.key,required this.store});@override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('מידע')),body:ListView(padding:const EdgeInsets.all(16),children:[
  Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(color:card,borderRadius:BorderRadius.circular(24)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('במה',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900)),const SizedBox(height:5),const Text('הופעות מסודרות. שירים מוכנים. אקורדים ברורים.',style:TextStyle(color:soft)),const SizedBox(height:18),Text(store.lists.length.toString()+' רשימות  •  '+store.songs.length.toString()+' שירים',style:const TextStyle(fontWeight:FontWeight.bold))])),
  const SizedBox(height:12),const ListTile(leading:Icon(Icons.style),title:Text('חלוקה לפי סגנון'),subtitle:Text('בתוך כל רשימת הופעה יש מעבר מהיר בין סגנונות.')),
  const ListTile(leading:Icon(Icons.text_fields),title:Text('זיהוי אקורדים'),subtitle:Text('C, Am, Dm7, G/B ועוד מזוהים אוטומטית.')),
  const ListTile(leading:Icon(Icons.picture_as_pdf),title:Text('TXT ו-PDF'),subtitle:Text('ייבוא קובץ והפיכתו לשיר מסודר. PDF סרוק כתמונה דורש OCR.')),
]));}
