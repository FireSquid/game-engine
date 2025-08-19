pub const GameState = enum {
    failed, // Error state
    none, // No state, used for the previous state on initial startup
    cancelled, // Game is cancelled or ended abnormally

    terminated, // Game is over, post-game stats available
    ending, // Game has ended normally, processing game score

    lobby, // Waiting for player and rules setup
    setup, // Setting up initial game state

    wait_orders, // Waiting for players to submit orders
    turn_end, // Processing turn
};

test {
    @import("std").testing.refAllDecls(@This());
}
