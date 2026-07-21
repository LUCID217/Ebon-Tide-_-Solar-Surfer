// Thin input layer between the OS and gameplay. Player code only reads the
// normalized snapshot this exposes (moveX/moveY, aim point, fire/ability
// held), so a gamepad or touch layer later just writes the same fields.

export default class InputController {
  constructor(scene) {
    this.scene = scene;
    this.keys = scene.input.keyboard.addKeys({
      up: 'W', down: 'S', left: 'A', right: 'D',
      up2: 'UP', down2: 'DOWN', left2: 'LEFT', right2: 'RIGHT',
      ability: 'SHIFT'
    });

    this.moveX = 0;
    this.moveY = 0;
    this.aimX = 0;       // world-space aim point
    this.aimY = 0;
    this.firing = false;
    this.abilityHeld = false;

    // right mouse also triggers the ability
    scene.input.mouse?.disableContextMenu();
  }

  update() {
    const k = this.keys;
    let x = (k.right.isDown || k.right2.isDown ? 1 : 0) - (k.left.isDown || k.left2.isDown ? 1 : 0);
    let y = (k.down.isDown || k.down2.isDown ? 1 : 0) - (k.up.isDown || k.up2.isDown ? 1 : 0);
    if (x !== 0 && y !== 0) { // normalize diagonals
      const inv = 1 / Math.SQRT2;
      x *= inv; y *= inv;
    }
    this.moveX = x;
    this.moveY = y;

    const pointer = this.scene.input.activePointer;
    pointer.updateWorldPoint(this.scene.cameras.main);
    this.aimX = pointer.worldX;
    this.aimY = pointer.worldY;

    this.firing = pointer.leftButtonDown();
    this.abilityHeld = k.ability.isDown || pointer.rightButtonDown();
  }
}
