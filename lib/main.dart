import 'package:flutter/material.dart';
import 'package:flutter/animation.dart';
import 'package:flute_music_player/flute_music_player.dart';
import 'package:flutter_music/shared/widgets/song_title.dart';
import 'package:flutter_music/shared/widgets/page_loading.dart';
import 'package:flutter_music/shared/widgets/playing_song.dart';
import 'package:flutter_music/shared/widgets/overflow_text.dart';
import 'package:flutter_music/shared/widgets/empty_songs.dart';

import 'package:flutter_music/shared/player_state.dart';

void main() => runApp(MyApp());
MusicFinder audioPlayer;
const int yoff = 3;

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  List<Song> _songs = <Song>[]; // 本地音乐列表
  PlayerState playerState; // 播放状态
  Song playingSong; // 正在播放的音乐
  int currentSongIndex; // 正在播放音乐的index

  // 下一首歌
  Song get nextSong {
    currentSongIndex++;
    playingSong = _songs[currentSongIndex];
    Song ns = _songs[currentSongIndex % _songs.length];
    return ns;
  }

  bool _isLoading = true; // 是否在加载(songs)状态
  Duration duration;
  Duration position;
  Animation<Offset> bottomViewAnimation;
  AnimationController bottomViewAnimationCtrl;

  @override
  void initState() {
    super.initState();
    _initPlayer();
    _initBottomViewAnimation();
  }

  @override
  void dispose() {
    bottomViewAnimationCtrl.dispose();
    super.dispose();
  }

  @override
  void reassemble() {
    _initPlayer();
    _initBottomViewAnimation();
    super.reassemble();
  }

  /**
   * * 初始化获取用户本地的音乐列表
   */
  void _initPlayer() async {
    _isLoading = true;
    var songs = await MusicFinder.allSongs();
    setState(() {
      _songs = songs;
      _isLoading = false;
    });

    audioPlayer ??= new MusicFinder();
    audioPlayer.setDurationHandler((Duration d) => setState(() {
          // 持续时间
          duration = d;
        }));

    audioPlayer.setPositionHandler((Duration p) => setState(() {
          // 位置
          position = p;
        }));

    audioPlayer.setCompletionHandler(() {
      // 完成时
      onComplete();
      setState(() {
        position = duration;
      });
    });
  }

  /**
   * * 初始化底部悬浮view的动画
   */
  void _initBottomViewAnimation() {
    bottomViewAnimationCtrl = new AnimationController(
      duration: const Duration(
        milliseconds: 600,
      ),
      vsync: this,
    );
    bottomViewAnimation = Tween<Offset>(
      begin: Offset(0, 0),
      end: Offset(0, 1), // y轴偏移量+height
    ).animate(bottomViewAnimationCtrl);
  }

  // 播放
  play(songUrl) async {
    final result = await audioPlayer.play(songUrl);
    if (result == 1) setState(() => playerState = PlayerState.playing);
  }

  // 播放
  playLocal(songUrl) async {
    final result = await audioPlayer.play(songUrl);
    if (result == 1) setState(() => playerState = PlayerState.playing);
  }

  // 暂停音乐
  pause() async {
    final result = await audioPlayer.pause();
    if (result == 1) setState(() => playerState = PlayerState.paused);
  }

  // 结束音乐
  stop() async {
    final result = await audioPlayer.stop();
    if (result == 1) setState(() => playerState = PlayerState.stopped);
  }

  // 完成一首后，进入下一首
  void onComplete() {
    setState(() => playerState = PlayerState.stopped);
    playLocal(nextSong.uri);
  }

  // 切换了正在播放的音乐事件
  void _switchMusic(Song clickedSong) async {
    playingSong = clickedSong;
    await stop();
    await playLocal(playingSong.uri);
  }

  // 监听ListView滚动事件
  bool _onNotification(Notification notification) {
    if (notification is ScrollUpdateNotification && notification.depth == 0) {
      var d = notification.dragDetails;
      if (d != null && d.delta != null) {
        var dy = d.delta.dy;
        if (dy > yoff) {
          // 向下滑动
          bottomViewAnimationCtrl.reverse();
        } else if (dy < -yoff) {
          // 向上滑动
          bottomViewAnimationCtrl.forward();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget home() {
      if (!_isLoading) {
        return new Scaffold(
          appBar: AppBar(title: Text('Music App')),
          body: _songs.isEmpty
              ? EmptySongs()
              : Stack(
                  children: <Widget>[
                    NotificationListener(
                      onNotification: _onNotification,
                      child: ListView.builder(
                        itemCount: _songs.length,
                        itemBuilder: (context, int index) {
                          Song tapSong = _songs[index];
                          return new ListTile(
                            leading: SongTitle(
                              tapSong.albumArt == null
                                  ? Text(tapSong.title[0])
                                  : tapSong.albumArt,
                            ),
                            subtitle: OverflowText(tapSong.artist),
                            title: OverflowText(tapSong.title),
                            onTap: () async {
                              currentSongIndex = index;

                              // print(s.id); // 23117
                              // print(s.album); // ジョジョの奇妙な冒険 O.S.T Battle Tendency [Leicht Verwendbar]
                              // print(s.albumArt); // /storage/emulated/0/Android/data/com.android.providers.media/albumthumbs/1556812126330
                              // print(s.albumId); // 7
                              // print(s.artist);//岩崎琢
                              // print(s.duration);//201638
                              // print(s.title);//Awake
                              // print(s.uri);// /storage/emulated/0/netease/cloudmusic/Music/岩崎琢 - Awake.mp3

                              if (playerState == PlayerState.playing) {
                                // 暂停
                                print('暂停');
                                // 在列表上点击你应该使用"stop()"而不是"pause()",因为stop会让song真正的结束。
                                if (tapSong == playingSong) {
                                  await pause();
                                } else {
                                  _switchMusic(tapSong);
                                }
                              } else {
                                // 播放
                                print('播放');
                                if (playingSong == null) {
                                  // 第一次进入直接播放点击歌曲
                                  playingSong = tapSong;
                                  await playLocal(playingSong.uri);
                                } else if (tapSong != playingSong) {
                                  // 在列表中点击了其他歌曲
                                  _switchMusic(tapSong);
                                } else if (tapSong == playingSong) {
                                  // 点击了同一首歌曲
                                  await playLocal(playingSong.uri);
                                }
                              }
                            },
                          );
                        },
                      ),
                    ),
                    PlayingSongView(
                      playingSong: playingSong,
                      position: bottomViewAnimation,
                      playerState: playerState,
                      pause: pause,
                      playLocal: playLocal,
                    ),
                  ],
                ),
        );
      } else {
        return PageLoading(
          body: Text('加载中...'),
        );
      }
    }

    return new MaterialApp(
      home: home(),
    );
  }
}
