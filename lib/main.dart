import 'dart:convert';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

const primary = Color(0xFF7C6CFF);
const chorusColor = Color(0xFFFF7A59);
const bridgeColor = Color(0xFF2EC4A6);
const verseColor = Color(0xFF4D96FF);
const otherColor = Color(0xFF8E8E9A);
const chordColor = Color(0xFFFFD166);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = Store();
  await store.load();
  runApp(App(store));
}

String uid() => DateTime.now().microsecondsSinceEpoch.toString();

class Folder {
  String id, name;
  Folder(this.id, this.name);
  Map<String,dynamic> toJson() => {'id':id,'name':name};
  factory Folder.fromJson(Map<String,dynamic> j) => Folder(j['id'], j['name']);
}

class Song {
  String id, title, folder, key, text;
  int semi;
  Song(this.id,this.title,this.folder,this.key,this.text,[this.semi=0]);
  Map<String,dynamic> toJson()=>{'id':id,'title':title,'folder':folder,'key':key,'text':text,'semi':semi};
  factory Song.fromJson(Map<String,dynamic> j)=>Song(j['id'],j['title'],j['folder'],j['key'] ?? 'C',j['text'] ?? '',j['semi'] ?? 0);
}

class Store extends ChangeNotifier {
  final folders=<Folder>[];
  final songs=<Song>[];
  double speed=25, font=24;
  bool stage=false;
  late SharedPreferences prefs;

  Future<void> load() async {
    prefs=await SharedPreferences.getInstance();
    final raw=prefs.getString('bama');
    if(raw==null){ seed(); await save(); return; }
    try{
      final j=jsonDecode(raw);
      folders..clear()..addAll((j['folders'] as List).map((x)=>Folder.fromJson(Map<String,dynamic>.from(x))));
      songs..clear()..addAll((j['songs'] as List).map((x)=>Song.fromJson(Map<String,dynamic>.from(x))));
      speed=(j['speed'] ?? 25).toDouble();
      font=(j['font'] ?? 24).toDouble();
      stage=j['stage']==true;
      if(folders.isEmpty) folders.add(Folder(uid(),'הופעה'));
    }catch(_){seed(); await save();}
    notifyListeners();
  }

  void seed(){
    folders..clear()
      ..add(Folder('f1','הופעה – יום שישי'))
      ..add(Folder('f2','חזרות'));
    songs..clear()
      ..add(Song('s1','אור של בוקר','f1','Am',
'''# בית
[Am]אור של [F]בוקר עולה
[C]פותח את [G]הלב

# פזמון
[F]בוא נרים [G]קול
[Em]ונשיר [Am]ביחד
[F]עוד יום [G]חדש [C]מתחיל'''))
      ..add(Song('s2','דרך חדשה','f2','C',
'''# בית
[C]יוצאים ל[Am]דרך
[F]צעד אחרי [G]צעד

# מעבר
[Am] [F] [C] [G]

# פזמון
[F]יש לנו [G]כוח
[Em]לפתוח [Am]דלת
[F]אל מקום [G]חדש [C]'''));
  }

  Future<void> save() async {
    await prefs.setString('bama',jsonEncode({'folders':folders.map((x)=>x.toJson()).toList(),'songs':songs.map((x)=>x.toJson()).toList(),'speed':speed,'font':font,'stage':stage}));
    notifyListeners();
  }
  void settings({double? s,double? f,bool? m}){if(s!=null)speed=s;if(f!=null)font=f;if(m!=null)stage=m;save();}
  void putSong(Song s){final i=songs.indexWhere((x)=>x.id==s.id);if(i<0)songs.add(s);else songs[i]=s;save();}
  void delSong(Song s){songs.removeWhere((x)=>x.id==s.id);save();}
  void addFolder(String n){folders.add(Folder(uid(),n));save();}
  void delFolder(Folder f){if(folders.length>1 && !songs.any((s)=>s.folder==f.id)){folders.remove(f);save();}}
}

class App extends StatelessWidget {
  final Store store;
  const App(this.store,{super.key});
  @override Widget build(BuildContext c)=>AnimatedBuilder(
    animation:store,
    builder:(_,__)=>MaterialApp(
      debugShowCheckedModeBanner:false,title:'במה',
      theme:ThemeData(useMaterial3:true,brightness:Brightness.dark,colorScheme:ColorScheme.fromSeed(seedColor:primary,brightness:Brightness.dark),scaffoldBackgroundColor:const Color(0xFF101014)),
      home:Directionality(textDirection:TextDirection.rtl,child:Library(store)),
    ),
  );
}

class Library extends StatefulWidget {
  final Store store;
  const Library(this.store,{super.key});
  @override State<Library> createState()=>_LibraryState();
}
class _LibraryState extends State<Library>{
  String? folder;
  @override void initState(){super.initState();folder=widget.store.folders.first.id;}
  void snack(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  Future<void> newFolder()async{
    final c=TextEditingController();
    final n=await showDialog<String>(context:context,builder:(_)=>AlertDialog(title:const Text('תיקייה חדשה'),content:TextField(controller:c,autofocus:true,decoration:const InputDecoration(labelText:'שם התיקייה')),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('ביטול')),FilledButton(onPressed:()=>Navigator.pop(context,c.text),child:const Text('צור'))]));
    if(n!=null&&n.trim().isNotEmpty){widget.store.addFolder(n.trim());setState(()=>folder=widget.store.folders.last.id);}
  }
  Future<void> importFile()async{
    try{
      final r=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['txt','pdf'],withData:true);
      if(r==null||r.files.single.bytes==null)return;
      final f=r.files.single;
      String text;
      if(f.extension?.toLowerCase()=='pdf'){
        final doc=PdfDocument(inputBytes:f.bytes!);
        text=PdfTextExtractor(doc).extractText(layoutText:true);
        doc.dispose();
      }else{text=utf8.decode(f.bytes!,allowMalformed:true);}
      final s=Song(uid(),f.name.replaceFirst(RegExp(r'\.[^.]+$'),''),folder!, 'C',Converter.convert(text));
      if(!mounted)return;
      await Navigator.push(context,MaterialPageRoute(builder:(_)=>Editor(widget.store,s,true)));
      setState((){});
    }catch(e){if(mounted)snack('הייבוא נכשל: '+e.toString());}
  }
  @override Widget build(BuildContext c){
    final list=widget.store.songs.where((s)=>s.folder==folder).toList();
    return Scaffold(
      appBar:AppBar(title:const Text('במה',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900)),actions:[IconButton(tooltip:'הגדרות',onPressed:()=>settings(),icon:const Icon(Icons.settings_outlined))]),
      body:Column(children:[
        SizedBox(height:62,child:ListView.separated(scrollDirection:Axis.horizontal,padding:const EdgeInsets.all(8),itemCount:widget.store.folders.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(_,i){
          final f=widget.store.folders[i];
          return GestureDetector(onLongPress:(){
            if(widget.store.folders.length==1){snack('אי אפשר למחוק את התיקייה האחרונה');return;}
            if(widget.store.songs.any((s)=>s.folder==f.id)){snack('אפשר למחוק רק תיקייה ריקה');return;}
            widget.store.delFolder(f);setState(()=>folder=widget.store.folders.first.id);
          },child:FilterChip(label:Text(f.name),selected:f.id==folder,onSelected:(_)=>setState(()=>folder=f.id)));
        })),
        Expanded(child:list.isEmpty?const Center(child:Text('אין שירים בתיקייה')):ListView.builder(padding:const EdgeInsets.all(14),itemCount:list.length,itemBuilder:(_,i){
          final s=list[i];
          return Card(child:ListTile(
            leading:CircleAvatar(child:Text((i+1).toString())),
            title:Text(s.title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.bold)),
            subtitle:Text('מקורי: '+s.key),
            trailing:Text(transposeKey(s.key,s.semi),style:const TextStyle(color:chordColor,fontWeight:FontWeight.w900,fontSize:20)),
            onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Player(widget.store,s))),
            onLongPress:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Editor(widget.store,s))),
          ));
        })),
      ]),
      floatingActionButton:Wrap(spacing:8,children:[
        FloatingActionButton.extended(heroTag:'f',onPressed:newFolder,icon:const Icon(Icons.create_new_folder_outlined),label:const Text('תיקייה חדשה')),
        FloatingActionButton.extended(heroTag:'i',onPressed:importFile,icon:const Icon(Icons.file_upload_outlined),label:const Text('ייבוא קובץ')),
        FloatingActionButton.extended(heroTag:'s',backgroundColor:primary,onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>Editor(widget.store,Song(uid(),'שיר חדש',folder!,'C','# בית\\n'),true))),icon:const Icon(Icons.add),label:const Text('שיר חדש')),
      ]),
    );
  }
  void settings()=>showModalBottomSheet(context:context,builder:(_)=>StatefulBuilder(builder:(c,setSheet)=>Padding(padding:const EdgeInsets.all(20),child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Text('הגדרות',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),
    Text('מהירות: '+widget.store.speed.toStringAsFixed(0)),
    Slider(min:5,max:80,value:widget.store.speed,onChanged:(v){setSheet((){});widget.store.settings(s:v);}),
    Text('גודל גופן: '+widget.store.font.toStringAsFixed(0)),
    Slider(min:16,max:40,value:widget.store.font,onChanged:(v){setSheet((){});widget.store.settings(f:v);}),
    SwitchListTile(title:const Text('מצב במה'),value:widget.store.stage,onChanged:(v){setSheet((){});widget.store.settings(m:v);}),
  ])));
}

class Editor extends StatefulWidget{
  final Store store; final Song song; final bool isNew;
  const Editor(this.store,this.song,[this.isNew=false],{super.key});
  @override State<Editor> createState()=>_EditorState();
}
class _EditorState extends State<Editor>{
  late TextEditingController title,key,text; late String folder; final focus=FocusNode();
  @override void initState(){super.initState();title=TextEditingController(text:widget.song.title);key=TextEditingController(text:widget.song.key);text=TextEditingController(text:widget.song.text);folder=widget.song.folder;}
  @override void dispose(){title.dispose();key.dispose();text.dispose();focus.dispose();super.dispose();}
  void insert(String v){final a=text.selection.isValid?text.selection.start:text.text.length;final b=text.selection.isValid?text.selection.end:a;text.value=text.value.copyWith(text:text.text.replaceRange(a,b,v),selection:TextSelection.collapsed(offset:a+v.length));focus.requestFocus();}
  void saveSong(){widget.store.putSong(Song(widget.song.id,title.text.trim().isEmpty?'שיר ללא שם':title.text.trim(),folder,key.text.trim().isEmpty?'C':key.text.trim(),text.text,widget.song.semi));Navigator.pop(context);}
  Future<void> del()async{if(widget.isNew){Navigator.pop(context);return;}final ok=await showDialog<bool>(context:context,builder:(_)=>AlertDialog(title:const Text('מחיקת שיר'),content:Text('למחוק את \"'+widget.song.title+'\"?'),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('ביטול')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:const Text('מחיקה'))]))??false;if(ok){widget.store.delSong(widget.song);Navigator.pop(context);}}
  @override Widget build(BuildContext c)=>Scaffold(
    appBar:AppBar(title:const Text('עורך'),actions:[IconButton(tooltip:'שמור',onPressed:saveSong,icon:const Icon(Icons.save_outlined))]),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      TextField(controller:title,decoration:const InputDecoration(labelText:'שם השיר')),
      const SizedBox(height:10),
      DropdownButtonFormField<String>(value:folder,decoration:const InputDecoration(labelText:'תיקייה'),items:widget.store.folders.map((f)=>DropdownMenuItem(value:f.id,child:Text(f.name))).toList(),onChanged:(v)=>setState(()=>folder=v!)),
      const SizedBox(height:10),
      TextField(controller:key,decoration:const InputDecoration(labelText:'סולם מקורי',hintText:'C / Am / F#')),
      const SizedBox(height:14),
      const Text('הוספת חלק',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      Wrap(spacing:6,children:[['בית','# בית'],['פזמון','# פזמון'],['מעבר','# מעבר'],['פתיחה','# פתיחה'],['סיום','# סיום']].map((x)=>ActionChip(label:Text(x[0]),onPressed:()=>insert(text.text.isEmpty?x[1]+'\\n':'\\n'+x[1]+'\\n'))).toList()),
      const SizedBox(height:14),
      const Text('אקורדים נפוצים',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
      Wrap(spacing:5,children:['C','G','Am','F','Dm','Em','A','D','E','Bm','C7','G7'].map((x)=>ActionChip(label:Text(x),onPressed:()=>insert('['+x+']'))).toList()),
      const SizedBox(height:14),
      TextField(controller:text,focusNode:focus,minLines:18,maxLines:30,style:const TextStyle(fontSize:17,height:1.4),decoration:const InputDecoration(labelText:'טקסט השיר',alignLabelWithHint:true)),
      const SizedBox(height:14),
      Row(children:[Expanded(child:FilledButton.icon(onPressed:saveSong,icon:const Icon(Icons.save),label:const Text('שמירה'))),if(!widget.isNew)const SizedBox(width:8),if(!widget.isNew)Expanded(child:OutlinedButton.icon(onPressed:del,icon:const Icon(Icons.delete_outline),label:const Text('מחיקה')))])
    ])
  );
}

class Player extends StatefulWidget{
  final Store store; final Song song;
  const Player(this.store,this.song,{super.key});
  @override State<Player> createState()=>_PlayerState();
}
class _PlayerState extends State<Player> with SingleTickerProviderStateMixin{
  late ScrollController scroll; late Ticker ticker; late List<Section> sections;
  bool playing=false,userScroll=false,animating=false; int active=0; Duration? last; double speed=25,font=24;
  @override void initState(){super.initState();scroll=ScrollController();ticker=createTicker(tick);sections=parseSections(widget.song.text);speed=widget.store.speed;font=widget.store.font;scroll.addListener(updateActive);}
  @override void dispose(){scroll.removeListener(updateActive);ticker.dispose();scroll.dispose();super.dispose();}
  void updateActive(){if(!scroll.hasClients)return;int next=0;for(int i=0;i<sections.length;i++){final ctx=sections[i].key.currentContext;if(ctx!=null){final b=ctx.findRenderObject();if(b is RenderBox&&b.localToGlobal(Offset.zero).dy<=190)next=i;}}if(next!=active&&mounted)setState(()=>active=next);}
  void tick(Duration now){
    if(!playing||userScroll||animating||!scroll.hasClients){last=now;return;}
    final prev=last??now;final dt=(now-prev).inMicroseconds/1000000;last=now;
    final next=scroll.offset+speed*dt;
    if(next>=scroll.position.maxScrollExtent){scroll.jumpTo(scroll.position.maxScrollExtent);setState(()=>playing=false);ticker.stop();}else{scroll.jumpTo(next);}
  }
  void play(){setState(()=>playing=!playing);if(playing){last=null;ticker.start();}else{ticker.stop();}}
  Future<void> jump(int i)async{if(i<0||i>=sections.length)return;setState(()=>animating=true);try{await Scrollable.ensureVisible(sections[i].key.currentContext!,duration:const Duration(milliseconds:350),curve:Curves.easeOut,alignment:.05);}finally{if(mounted)setState(()=>animating=false);}}
  Future<void> next(String type)async{
    if(sections.isEmpty)return;
    int cur=0;
    for(int i=0;i<sections.length;i++){final ctx=sections[i].key.currentContext;if(ctx!=null){final b=ctx.findRenderObject();if(b is RenderBox&&b.localToGlobal(Offset.zero).dy<=190)cur=i;}}
    for(int pass=0;pass<2;pass++){final start=pass==0?cur+1:0;final end=pass==0?sections.length:cur+1;for(int i=start;i<end;i++){if(sections[i].type==type){await jump(i);return;}}}
  }
  void transpose(int d){widget.song.semi+=d;widget.store.save();setState((){});}
  @override Widget build(BuildContext c){
    final stage=widget.store.stage;final bg=stage?Colors.black:const Color(0xFF101014);
    return Scaffold(backgroundColor:bg,appBar:AppBar(backgroundColor:bg,title:Text(widget.song.title,style:const TextStyle(fontWeight:FontWeight.w900)),actions:[
      IconButton(tooltip:'הקטן גופן',onPressed:()=>setState(()=>font=math.max(16,font-1)),icon:const Icon(Icons.text_decrease)),
      IconButton(tooltip:'הגדל גופן',onPressed:()=>setState(()=>font=math.min(40,font+1)),icon:const Icon(Icons.text_increase)),
      IconButton(tooltip:'עריכה',onPressed:()async{await Navigator.push(context,MaterialPageRoute(builder:(_)=>Editor(widget.store,widget.song)));setState(()=>sections=parseSections(widget.song.text));},icon:const Icon(Icons.edit_outlined)),
      IconButton(tooltip:'מצב במה',onPressed:()=>widget.store.settings(m:!stage),icon:Icon(stage?Icons.light_mode_outlined:Icons.dark_mode_outlined)),
    ]),
    body:Column(children:[
      SongMap(sections:sections,active:active,onTap:jump),
      if(sections.isNotEmpty)Padding(padding:const EdgeInsets.symmetric(horizontal:16,vertical:3),child:Align(alignment:Alignment.centerRight,child:Text(sections[active].name,style:TextStyle(color:sectionColor(sections[active].type),fontWeight:FontWeight.bold)))),
      Expanded(child:NotificationListener<ScrollNotification>(onNotification:(n){if(n is UserScrollNotification)userScroll=n.direction!=ScrollDirection.idle;if(n is ScrollEndNotification)userScroll=false;return false;},child:ListView.builder(controller:scroll,padding:const EdgeInsets.fromLTRB(12,8,12,190),itemCount:sections.length,itemBuilder:(_,i)=>SectionView(section:sections[i],font:font,stage:stage,semi:widget.song.semi)))),
      Dock(playing:playing,speed:speed,keyName:transposeKey(widget.song.key,widget.song.semi),onPlay:play,onSpeed:(v){setState(()=>speed=v);widget.store.settings(s:v);},onTranspose:transpose,onNext:next)
    ]));
  }
}

class Dock extends StatelessWidget{
  final bool playing; final double speed; final String keyName; final VoidCallback onPlay; final ValueChanged<double> onSpeed; final ValueChanged<int> onTranspose; final Future<void> Function(String) onNext;
  const Dock({super.key,required this.playing,required this.speed,required this.keyName,required this.onPlay,required this.onSpeed,required this.onTranspose,required this.onNext});
  Widget b(String t,Color col,String type)=>Expanded(child:FilledButton(style:FilledButton.styleFrom(backgroundColor:col.withValues(alpha:.22),foregroundColor:col,minimumSize:const Size(0,52),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),onPressed:()=>onNext(type),child:Text(t,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900))));
  @override Widget build(BuildContext c)=>Material(color:const Color(0xFF19191F),elevation:18,child:SafeArea(top:false,child:Padding(padding:const EdgeInsets.all(8),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Row(children:[b('בית',verseColor,'verse'),const SizedBox(width:6),b('פזמון',chorusColor,'chorus'),const SizedBox(width:6),b('מעבר',bridgeColor,'bridge')]),
    Row(children:[IconButton.filled(tooltip:playing?'עצור':'הפעל',onPressed:onPlay,icon:Icon(playing?Icons.pause:Icons.play_arrow)),Expanded(child:Slider(min:5,max:80,value:speed.clamp(5,80),onChanged:onSpeed)),Text(speed.toStringAsFixed(0)),IconButton(tooltip:'חצי טון למטה',onPressed:()=>onTranspose(-1),icon:const Icon(Icons.remove_circle_outline)),Text(keyName,style:const TextStyle(color:chordColor,fontSize:19,fontWeight:FontWeight.w900)),IconButton(tooltip:'חצי טון למעלה',onPressed:()=>onTranspose(1),icon:const Icon(Icons.add_circle_outline))])
  ])));
}

class SongMap extends StatelessWidget{
  final List<Section> sections; final int active; final ValueChanged<int> onTap;
  const SongMap({super.key,required this.sections,required this.active,required this.onTap});
  @override Widget build(BuildContext c)=>SizedBox(height:42,child:Padding(padding:const EdgeInsets.symmetric(horizontal:10),child:Row(children:List.generate(sections.length,(i){
    final s=sections[i];return Expanded(flex:math.max(1,s.lines.length),child:Padding(padding:const EdgeInsets.symmetric(horizontal:1),child:InkWell(onTap:()=>onTap(i),child:Container(decoration:BoxDecoration(color:sectionColor(s.type).withValues(alpha:i==active ? .95 : .24),borderRadius:BorderRadius.circular(7),border:i==active?Border.all(color:Colors.white,width:1.2):null),alignment:Alignment.center,child:Text(s.name,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold))))));
  }))));
}

class Section{
  final String name,type; final List<String> lines; final key=GlobalKey();
  Section(this.name,this.type,this.lines);
}
List<Section> parseSections(String raw){
  final out=<Section>[];String name='אחר',type='other';var body=<String>[];
  void flush(){if(body.isNotEmpty||out.isEmpty){out.add(Section(name,type,List.of(body)));}body=[];}
  for(final line in raw.replaceAll('\\r','').split('\\n')){
    if(line.trimLeft().startsWith('#')){flush();name=line.trimLeft().substring(1).trim();type=sectionType(name);}else if(line.isNotEmpty||body.isNotEmpty)body.add(line);
  }
  if(body.isNotEmpty)flush();return out;
}
String sectionType(String n){final x=n.toLowerCase();if(x.contains('פזמון')||x.contains('chorus'))return 'chorus';if(x.contains('מעבר')||x.contains('גשר')||x.contains('bridge'))return 'bridge';if(x.contains('בית')||x.contains('verse'))return 'verse';return 'other';}
Color sectionColor(String t)=>t=='chorus'?chorusColor:t=='bridge'?bridgeColor:t=='verse'?verseColor:otherColor;

class SectionView extends StatelessWidget{
  final Section section;final double font;final bool stage;final int semi;
  const SectionView({super.key,required this.section,required this.font,required this.stage,required this.semi});
  @override Widget build(BuildContext c)=>Container(key:section.key,margin:const EdgeInsets.only(bottom:22),decoration:BoxDecoration(color:stage?Colors.black:const Color(0xFF15151B),borderRadius:BorderRadius.circular(14)),child:IntrinsicHeight(child:Row(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
    Container(width:7,decoration:BoxDecoration(color:sectionColor(section.type),borderRadius:BorderRadius.circular(7))),
    Expanded(child:Padding(padding:const EdgeInsets.fromLTRB(12,9,10,12),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text(section.name,style:TextStyle(color:sectionColor(section.type),fontWeight:FontWeight.w900)),
      const SizedBox(height:7),
      ...section.lines.map((l)=>Padding(padding:const EdgeInsets.only(bottom:10),child:ChordLine(l,font,semi)))
    ])))
  ])));
}

class ChordLine extends StatelessWidget{
  final String line;final double font;final int semi;
  const ChordLine(this.line,this.font,this.semi,{super.key});
  @override Widget build(BuildContext c){
    final tokens=parseTokens(line);
    if(tokens.length==1&&tokens.first.$1==null)return Text(line,style:TextStyle(fontSize:font,height:1.3));
    return Wrap(spacing:2,runSpacing:7,crossAxisAlignment:WrapCrossAlignment.end,children:tokens.map((t)=>Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      SizedBox(height:font*.85,child:t.$1==null?null:Directionality(textDirection:TextDirection.ltr,child:Text(transposeChord(t.$1!,semi),style:TextStyle(fontFamily:'monospace',color:chordColor,fontWeight:FontWeight.w800,fontSize:math.max(13,font*.62))))),
      Text(t.$2.isEmpty?' ':t.$2,style:TextStyle(fontSize:font,height:1.15))
    ])).toList());
  }
}
List<(String?,String)> parseTokens(String line){
  final ms=RegExp(r'\[([^\]]+)\]').allMatches(line).toList();if(ms.isEmpty)return [(null,line)];
  final out=< (String?,String)>[];int p=0;
  for(final m in ms){
    final before=line.substring(p,m.start);if(before.isNotEmpty)out.add((null,before));
    out.add((m.group(1),''));
    p=m.end;
  }
  if(p<line.length)out.add((null,line.substring(p)));
  return out;
}

class Converter{
  static final chord=RegExp(r'^[A-G][#b]?(?:m|maj|dim|sus|add)?\d*(?:/[A-G][#b]?)?$');
  static final heading=RegExp(r'^(בית|פזמון|מעבר|גשר|פתיחה|סיום|intro|verse|chorus|bridge|outro)\b',caseSensitive:false);
  static String convert(String input){
    final a=input.replaceAll('\r','').split('\n'),out=<String>[];
    for(int i=0;i<a.length;i++){
      final line=a[i],t=line.trim();
      if(t.isEmpty){out.add('');continue;}
      if(line.contains('#')||RegExp(r'\[[^\]]+\]').hasMatch(line)){out.add(line);continue;}
      if(t.length<=21&&heading.hasMatch(t)){out.add('# '+t);continue;}
      final ms=RegExp(r'\S+').allMatches(line).toList();
      if(ms.isNotEmpty&&ms.every((m)=>chord.hasMatch(m.group(0)!))){
        if(i+1<a.length&&a[i+1].trim().isNotEmpty){
          var next=a[i+1];
          for(final m in ms.reversed){
            final at=m.start>next.length?next.length:m.start;
            if(at>next.length) next=next.padRight(at);
            next=next.substring(0,at)+'['+m.group(0)!+']'+next.substring(at);
          }
          out.add(next);
          i++;
        }else{
          out.add(ms.map((m)=>'['+m.group(0)!+']').join(' '));
        }
      }else{
        out.add(line);
      }
    }
    return out.join('\n');
  }
}

const chrom=['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];
int noteIndex(String n){
  n=n.replaceAll('Db','C#').replaceAll('Eb','D#').replaceAll('Gb','F#').replaceAll('Ab','G#').replaceAll('Bb','A#');
  return chrom.indexOf(n);
}
String moveNote(String n,int d){
  final i=noteIndex(n);
  if(i<0)return n;
  final v=(i+d)%12;
  return chrom[v<0?v+12:v];
}
String transposeChord(String chord,int d){
  final m=RegExp(r'^([A-G](?:#|b)?)(.*?)(?:/([A-G](?:#|b)?))?$').firstMatch(chord.trim());
  if(m==null)return chord;
  final root=moveNote(m.group(1)!,d);
  final suffix=m.group(2)??'';
  final bass=m.group(3);
  return bass==null?root+suffix:root+suffix+'/'+moveNote(bass,d);
}
String transposeKey(String key,int d)=>transposeChord(key,d);
