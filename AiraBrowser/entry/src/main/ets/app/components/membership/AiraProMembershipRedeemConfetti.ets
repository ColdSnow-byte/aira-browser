const REDEEM_CONFETTI_COLORS: string[] = [
  '#26CCFF',
  '#A25AFD',
  '#FF5E7E',
  '#88FF5A',
  '#FCFF42',
  '#FFA62D',
  '#FF36FF'
];
const REDEEM_CONFETTI_FRAME_MS: number = 16;

class MembershipConfettiPiece {
  x: number = 0;
  y: number = 0;
  velocity: number = 0;
  angle: number = 0;
  wobble: number = 0;
  wobbleSpeed: number = 0.08;
  tilt: number = 0;
  tiltSpeed: number = 0.1;
  color: string = '#FF5E7E';
  width: number = 8;
  height: number = 4;
  tick: number = 0;
  totalTicks: number = 200;
  decay: number = 0.91;
  gravity: number = 0.24;
  drift: number = 0;
}

/**
 * Full-screen paper burst modeled on canvas-confetti's realistic cannon
 * (https://www.kirilv.com/canvas-confetti/#realistic). The motion is reimplemented
 * for ArkUI; the page itself is not embedded.
 */
@Component
export struct AiraProMembershipRedeemConfetti {
  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private pieces: MembershipConfettiPiece[] = [];
  private frameTimer: number = -1;
  private followUpTimer: number = -1;
  private canvasWidth: number = 0;
  private canvasHeight: number = 0;
  private canvasReady: boolean = false;
  private started: boolean = false;

  aboutToDisappear(): void {
    this.stop();
  }

  build() {
    Canvas(this.context)
      .width('100%')
      .height('100%')
      .backgroundColor(Color.Transparent)
      .hitTestBehavior(HitTestMode.None)
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        this.canvasWidth = this.readLength(newValue.width);
        this.canvasHeight = this.readLength(newValue.height);
        this.startIfReady();
      })
      .onReady(() => {
        this.canvasReady = true;
        this.startIfReady();
      })
  }

  private startIfReady(): void {
    if (this.started || !this.canvasReady || this.canvasWidth <= 0 || this.canvasHeight <= 0) {
      return;
    }
    this.started = true;
    this.fireRealisticBurst(1);
    this.followUpTimer = setTimeout((): void => {
      this.followUpTimer = -1;
      this.fireRealisticBurst(0.55);
    }, 90);
    this.frameTimer = setInterval((): void => {
      this.drawFrame();
    }, REDEEM_CONFETTI_FRAME_MS);
  }

  private fireRealisticBurst(scale: number): void {
    const count = Math.floor(220 * scale);
    this.spawn(Math.floor(count * 0.25), 26, 55, 0.9, 1);
    this.spawn(Math.floor(count * 0.2), 60, 45, 0.9, 1);
    this.spawn(Math.floor(count * 0.35), 100, 45, 0.91, 0.8);
    this.spawn(Math.floor(count * 0.1), 120, 25, 0.92, 1.2);
    this.spawn(Math.floor(count * 0.1), 120, 45, 0.9, 1);
  }

  private spawn(
    count: number,
    spreadDegrees: number,
    startVelocity: number,
    decay: number,
    scalar: number
  ): void {
    const originX = this.canvasWidth * 0.5;
    const originY = this.canvasHeight * 0.46;
    const spread = spreadDegrees * Math.PI / 180;
    const speed = startVelocity * this.speedScale();
    for (let index = 0; index < count; index++) {
      const piece = new MembershipConfettiPiece();
      piece.x = originX;
      piece.y = originY;
      piece.angle = -Math.PI / 2 + (Math.random() - 0.5) * spread;
      piece.velocity = speed * 0.45 + Math.random() * speed;
      piece.decay = decay;
      piece.wobble = Math.random() * 10;
      piece.wobbleSpeed = 0.05 + Math.random() * 0.06;
      piece.tilt = Math.random() * Math.PI;
      piece.tiltSpeed = 0.08 + Math.random() * 0.16;
      piece.color = REDEEM_CONFETTI_COLORS[index % REDEEM_CONFETTI_COLORS.length];
      piece.width = (7 + Math.random() * 8) * scalar;
      piece.height = (2.5 + Math.random() * 3.5) * scalar;
      piece.totalTicks = 170 + Math.floor(Math.random() * 50);
      piece.gravity = 0.18 + Math.random() * 0.1;
      piece.drift = (Math.random() - 0.5) * 0.6;
      this.pieces.push(piece);
    }
  }

  private drawFrame(): void {
    if (!this.canvasReady || this.canvasWidth <= 0 || this.canvasHeight <= 0) {
      return;
    }
    this.context.clearRect(0, 0, this.canvasWidth, this.canvasHeight);
    const alive: MembershipConfettiPiece[] = [];
    for (let index = 0; index < this.pieces.length; index++) {
      const piece = this.pieces[index];
      piece.x += Math.cos(piece.angle) * piece.velocity + piece.drift;
      piece.y += Math.sin(piece.angle) * piece.velocity + piece.gravity;
      piece.velocity *= piece.decay;
      piece.gravity += 0.035;
      piece.wobble += piece.wobbleSpeed;
      piece.tilt += piece.tiltSpeed;
      piece.tick += 1;
      if (piece.tick >= piece.totalTicks) {
        continue;
      }
      const alpha = 1 - piece.tick / piece.totalTicks;
      const flip = Math.max(0.12, Math.abs(Math.cos(piece.wobble)));
      this.context.save();
      this.context.translate(piece.x, piece.y);
      this.context.rotate(piece.tilt);
      this.context.scale(flip, 1);
      this.context.globalAlpha = alpha;
      this.context.fillStyle = piece.color;
      this.context.fillRect(-piece.width / 2, -piece.height / 2, piece.width, piece.height);
      this.context.restore();
      alive.push(piece);
    }
    this.pieces = alive;
    if (alive.length === 0 && this.followUpTimer < 0) {
      this.stop();
    }
  }

  private speedScale(): number {
    return Math.max(1, this.canvasWidth / 390);
  }

  private readLength(value: Length): number {
    const parsed = parseFloat(`${value}`);
    return Number.isFinite(parsed) ? parsed : 0;
  }

  private stop(): void {
    if (this.frameTimer >= 0) {
      clearInterval(this.frameTimer);
      this.frameTimer = -1;
    }
    if (this.followUpTimer >= 0) {
      clearTimeout(this.followUpTimer);
      this.followUpTimer = -1;
    }
  }
}
