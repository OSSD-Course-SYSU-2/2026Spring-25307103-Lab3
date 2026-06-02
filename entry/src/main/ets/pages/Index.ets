// ThunderFighter.ets
// 多端适配版 - 画布宽度自适应，元素等比缩放

import { mediaquery } from '@kit.ArkUI';
import { window } from '@kit.ArkUI';

interface Bullet {
  x: number;
  y: number;
}

interface Enemy {
  x: number;
  y: number;
  hp: number;
}

@Entry
@Component
struct ThunderFighter {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);

  @State playerX: number = 165;
  @State playerY: number = 550;
  @State score: number = 0;
  @State gameOver: boolean = false;
  @State message: string = '战斗开始！';
  @State GAME_WIDTH: number = 360;
  @State GAME_HEIGHT: number = 600;
  @State gameScale: number = 1.0;

  private readonly BASE_W: number = 360;
  private readonly PLAYER_S: number = 30;
  private readonly BULLET_W: number = 4;
  private readonly BULLET_H: number = 10;
  private readonly ENEMY_S: number = 25;
  private readonly MOVE: number = 20;
  private readonly B_SPD: number = 8;
  private readonly E_SPD: number = 3;

  private bullets: Bullet[] = [];
  private enemies: Enemy[] = [];
  private timer: number = -1;
  private spawnCount: number = 0;

  private listener: mediaquery.MediaQueryListener | null = null;

  @StorageLink('currentBreakpoint') currentBreakpoint: string = 'sm';

  initSize(): void {
    let w: number = 360;
    let h: number = 780;
    try {
      let ws = AppStorage.get<window.WindowStage>('windowStage');
      if (ws) {
        let win: window.Window = ws.getMainWindowSync();
        let rect: window.Rect = win.getWindowProperties().windowRect;
        w = rect.width;
        h = rect.height;
      }
    } catch (e) {
      // 使用默认值
    }

    let isLand: boolean = this.isLandscape();
    let isBig: boolean = this.currentBreakpoint === 'md' || this.currentBreakpoint === 'lg';

    if (isLand || isBig) {
      this.GAME_WIDTH = Math.floor(w * 0.6);
      this.GAME_HEIGHT = Math.floor(h * 0.8);
    } else {
      this.GAME_WIDTH = Math.floor(w * 0.92);
      this.GAME_HEIGHT = Math.floor(h * 0.5);
    }

    this.gameScale = this.GAME_WIDTH / this.BASE_W;
    this.playerX = (this.GAME_WIDTH - this.PLAYER_S * this.gameScale) / 2;
    this.playerY = this.GAME_HEIGHT - 50 * this.gameScale;
  }

  isLandscape(): boolean {
    try {
      let ws = AppStorage.get<window.WindowStage>('windowStage');
      if (ws) {
        let win: window.Window = ws.getMainWindowSync();
        let rect: window.Rect = win.getWindowProperties().windowRect;
        return rect.width > rect.height;
      }
    } catch (e) {
      // 忽略
    }
    return false;
  }

  aboutToAppear(): void {
    this.initSize();
    this.listener = mediaquery.matchMediaSync('(orientation: landscape)');
    if (this.listener) {
      this.listener.on('change', (): void => {
        this.stopGame();
        this.initSize();
        this.resetGame();
        this.startGame();
      });
    }
  }

  aboutToDisappear(): void {
    this.stopGame();
    if (this.listener) {
      this.listener.off('change');
    }
  }

  resetGame(): void {
    this.playerX = (this.GAME_WIDTH - this.PLAYER_S * this.gameScale) / 2;
    this.playerY = this.GAME_HEIGHT - 50 * this.gameScale;
    this.score = 0;
    this.gameOver = false;
    this.message = '战斗开始！';
    this.bullets = [];
    this.enemies = [];
    this.spawnCount = 0;
    this.draw();
  }

  draw(): void {
    let s: number = this.gameScale;
    let ctx: CanvasRenderingContext2D = this.context;
    ctx.clearRect(0, 0, this.GAME_WIDTH, this.GAME_HEIGHT);

    ctx.fillStyle = '#ffffff';
    for (let i: number = 0; i < 20; i++) {
      ctx.fillRect(i * (this.GAME_WIDTH / 20), (i * 30 * s + this.score * 2) % this.GAME_HEIGHT, 2 * s, 2 * s);
    }

    ctx.fillStyle = '#ffff00';
    for (let b of this.bullets) {
      ctx.fillRect(b.x, b.y, this.BULLET_W * s, this.BULLET_H * s);
    }

    for (let e of this.enemies) {
      ctx.fillStyle = e.hp > 1 ? '#ff6600' : '#ff0000';
      ctx.fillRect(e.x, e.y, this.ENEMY_S * s, this.ENEMY_S * s);
      ctx.fillStyle = '#000000';
      ctx.fillRect(e.x + 8 * s, e.y + 5 * s, 8 * s, 8 * s);
    }

    if (!this.gameOver) {
      let ps: number = this.PLAYER_S * s;
      ctx.fillStyle = '#ffffff';
      ctx.fillRect(this.playerX, this.playerY, ps, ps);
      ctx.fillStyle = '#88ccff';
      ctx.fillRect(this.playerX - 5 * s, this.playerY + 10 * s, 5 * s, 10 * s);
      ctx.fillRect(this.playerX + ps, this.playerY + 10 * s, 5 * s, 10 * s);
      ctx.fillStyle = '#ffdd00';
      ctx.fillRect(this.playerX + 10 * s, this.playerY + 5 * s, 10 * s, 10 * s);
    } else {
      ctx.fillStyle = '#ff0000';
      ctx.font = `${24 * s}px sans-serif`;
      ctx.textAlign = 'center';
      ctx.fillText('GAME OVER', this.GAME_WIDTH / 2, this.GAME_HEIGHT / 2);
      ctx.textAlign = 'left';
    }
  }

  update(): void {
    if (this.gameOver) {
      return;
    }

    let s: number = this.gameScale;
    let ps: number = this.PLAYER_S * s;
    let bw: number = this.BULLET_W * s;
    let bh: number = this.BULLET_H * s;
    let es: number = this.ENEMY_S * s;
    let bspd: number = this.B_SPD * s;
    let espd: number = this.E_SPD * s;

    for (let i: number = this.bullets.length - 1; i >= 0; i--) {
      this.bullets[i].y -= bspd;
      if (this.bullets[i].y < 0) {
        this.bullets.splice(i, 1);
      }
    }

    for (let i: number = this.enemies.length - 1; i >= 0; i--) {
      this.enemies[i].y += espd;
      if (this.enemies[i].y > this.GAME_HEIGHT) {
        this.gameOver = true;
        this.message = '敌机突破防线！';
      }
    }

    for (let i: number = this.bullets.length - 1; i >= 0; i--) {
      for (let j: number = this.enemies.length - 1; j >= 0; j--) {
        let b: Bullet = this.bullets[i];
        let e: Enemy = this.enemies[j];
        if (b.x < e.x + es && b.x + bw > e.x && b.y < e.y + es && b.y + bh > e.y) {
          this.bullets.splice(i, 1);
          e.hp--;
          if (e.hp <= 0) {
            this.enemies.splice(j, 1);
            this.score += 10;
            this.message = '击毁！+10分';
          }
          break;
        }
      }
    }

    for (let e of this.enemies) {
      if (this.playerX < e.x + es && this.playerX + ps > e.x &&
        this.playerY < e.y + es && this.playerY + ps > e.y) {
        this.gameOver = true;
        this.message = '撞机了！';
        break;
      }
    }

    this.spawnCount++;
    if (this.spawnCount >= 30) {
      this.spawnCount = 0;
      let enemy: Enemy = {
        x: Math.random() * (this.GAME_WIDTH - es),
        y: -es,
        hp: Math.random() > 0.7 ? 2 : 1
      };
      this.enemies.push(enemy);
    }

    this.draw();
  }

  startGame(): void {
    if (this.timer === -1) {
      this.timer = setInterval((): void => {
        this.update();
      }, 30);
    }
  }

  stopGame(): void {
    if (this.timer !== -1) {
      clearInterval(this.timer);
      this.timer = -1;
    }
  }

  move(dx: number, dy: number): void {
    if (this.gameOver) {
      return;
    }
    let ps: number = this.PLAYER_S * this.gameScale;
    let nx: number = this.playerX + dx;
    let ny: number = this.playerY + dy;
    if (nx >= 0 && nx <= this.GAME_WIDTH - ps) {
      this.playerX = nx;
    }
    if (ny >= 0 && ny <= this.GAME_HEIGHT - ps) {
      this.playerY = ny;
    }
    this.draw();
  }

  fire(): void {
    if (this.gameOver) {
      return;
    }
    let ps: number = this.PLAYER_S * this.gameScale;
    let bw: number = this.BULLET_W * this.gameScale;
    let bullet: Bullet = {
      x: this.playerX + ps / 2 - bw / 2,
      y: this.playerY - this.BULLET_H * this.gameScale
    };
    this.bullets.push(bullet);
    this.message = '发射！';
    this.draw();
  }

  build() {
    Column() {
      Text('⚡ 雷霆战机 ⚡')
        .fontSize(20).fontColor('#FFD700').fontWeight(FontWeight.Bold)
        .margin({ top: 5, bottom: 2 })

      Canvas(this.context)
        .width(this.GAME_WIDTH)
        .height(this.GAME_HEIGHT)
        .backgroundColor('#0a0a2e')
        .border({ width: 1, color: '#4444aa' })
        .onReady((): void => {
          this.draw();
          this.startGame();
        })

      Row() {
        Text(`🏆 ${this.score}`)
          .fontSize(16).fontColor('#FFD700').fontWeight(FontWeight.Bold)
        Text(this.message)
          .fontSize(12).fontColor('#ffffff').margin({ left: 10 }).maxLines(1)
      }.width('100%').padding(5).justifyContent(FlexAlign.SpaceBetween)

      Column({ space: 5 }) {
        Button('⬆️')
          .width(60).height(40).fontSize(18).backgroundColor('#3366cc')
          .onClick((): void => { this.move(0, -this.MOVE * this.gameScale); })
        Row({ space: 5 }) {
          Button('⬅️')
            .width(60).height(40).fontSize(18).backgroundColor('#3366cc')
            .onClick((): void => { this.move(-this.MOVE * this.gameScale, 0); })
          Button('⬇️')
            .width(60).height(40).fontSize(18).backgroundColor('#3366cc')
            .onClick((): void => { this.move(0, this.MOVE * this.gameScale); })
          Button('➡️')
            .width(60).height(40).fontSize(18).backgroundColor('#3366cc')
            .onClick((): void => { this.move(this.MOVE * this.gameScale, 0); })
        }
        Row({ space: 5 }) {
          Button('🔥')
            .width(80).height(40).fontSize(18).backgroundColor('#cc3333')
            .onClick((): void => { this.fire(); })
          Button('🔄')
            .width(80).height(40).fontSize(18).backgroundColor('#228822')
            .onClick((): void => {
              this.stopGame();
              this.resetGame();
              this.startGame();
            })
        }
      }.margin({ top: 5, bottom: 5 })
    }
    .width('100%').height('100%')
    .backgroundColor('#1a1a3e')
  }
}