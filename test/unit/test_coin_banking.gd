extends GutTest

# PRD-07 — the single run_coins → coins commit seam (bank_run_coins). Exercises
# the GameManager autoload; saves and restores the wallet so the suite leaves no
# residue. Does not touch disk (bank_run_coins itself never saves).

var _saved_coins: int
var _saved_run_coins: int


func before_each() -> void:
	_saved_coins = GameManager.coins
	_saved_run_coins = GameManager.run_coins


func after_each() -> void:
	GameManager.coins = _saved_coins
	GameManager.run_coins = _saved_run_coins


func test_bank_run_coins_commits_run_total_into_wallet() -> void:
	GameManager.coins = 100
	GameManager.run_coins = 50
	GameManager.bank_run_coins()
	assert_eq(GameManager.coins, 150, "run coins are added to the persisted wallet")
	assert_eq(GameManager.run_coins, 0, "run tally is zeroed after banking")


func test_bank_run_coins_is_idempotent() -> void:
	GameManager.coins = 0
	GameManager.run_coins = 30
	GameManager.bank_run_coins()
	GameManager.bank_run_coins()
	assert_eq(GameManager.coins, 30, "a second bank with nothing pending adds nothing")
	assert_eq(GameManager.run_coins, 0, "run tally stays zero")
