pragma solidity ^0.8.0;

import "solmate/auth/Owned.sol";
import {FixedPointMathLib} from "solady/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {LibPRNG} from "solady/utils/LibPRNG.sol";
import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";

contract zkTextPG is Owned {
    using FixedPointMathLib for uint256;
    using LibPRNG for *;

    struct Player {
        uint16 level;
        Item[] items;
    }

    struct Item {
        uint8 damageMultiplier;
    }

    struct Boss {
        uint16 hp;
        uint256 balance;
    }

    Boss[] public bosses;
    mapping(address => Player) public players;
    uint64 public constant ATTACK_FEE = 0.01 ether;
    uint8 private constant BASE_ATTACK = 100;
    uint8 private constant DIVISOR = 100;
    uint8 private constant FEE = 10;
    ERC20 public immutable token;
    uint8 public immutable decimals;
    LibPRNG.PRNG private generator;

    event ItemPurchased(address indexed _buyer, uint8 damageMultiplier);
    event AttackPerformed(address indexed attacker, uint16 damage, uint256 loot);
    event BossKilled(address indexed attacker, uint256 loot);
    event BossSpawned(Boss _boss);
    event PlayerCreated(address indexed _player);

    error PlayerNotCreated();

    modifier accountCreated() {
        if (players[msg.sender].level == 0) revert PlayerNotCreated();
        _;
    }

    constructor(address _token) Owned(msg.sender) {
        token = ERC20(_token);
        decimals = token.decimals();
        require(decimals > 0, "Invalid decimals");
        SafeTransferLib.safeTransferFrom(address(token), msg.sender, address(this), 100 * 10 ** decimals);
        _spawnBoss();
    }

    function createPlayer() external {
        require(players[msg.sender].level == 0, "Player already created");
        players[msg.sender].level = 1;
        emit PlayerCreated(msg.sender);
    }

    function buyItem() external accountCreated {
        generator.seed(block.timestamp);
        uint8 damageMultiplier = uint8(generator.next() % 10);
        players[msg.sender].items.push(Item(damageMultiplier));
        emit ItemPurchased(msg.sender, damageMultiplier);
    }

    function attack() external accountCreated {
        SafeTransferLib.safeTransferFrom(address(token), msg.sender, address(this), ATTACK_FEE);
        Boss storage currentBoss;
        if (!_isAlive(bosses.length - 1)) {
            currentBoss = _spawnBoss();
        } else {
            currentBoss = _currentBoss();
        }
        uint16 damage = _calculateDamage(msg.sender);
        uint16 bossHealth = _dealDamage(damage, currentBoss);

        if (bossHealth == 0) {
            uint256 fee = currentBoss.balance * FEE / DIVISOR;
            SafeTransferLib.safeTransfer(address(token), msg.sender, currentBoss.balance - fee);
            SafeTransferLib.safeTransfer(address(token), owner, fee);
            emit BossKilled(msg.sender, damage);
        } else {
            emit AttackPerformed(msg.sender, damage, 0);
        }
    }

    function _spawnBoss() internal returns (Boss storage) {
        bosses.push(Boss(1000, token.balanceOf(address(this))));
        emit BossSpawned(bosses[bosses.length - 1]);
        return bosses[bosses.length - 1];
    }

    function _calculateDamage(address user) internal view returns (uint16 damage) {
        uint16 damageMod = _calculateModifier(user);
        damage = damageMod * BASE_ATTACK;
        return damage;
    }

    function _calculateModifier(address _user) internal view returns (uint16 damageModifier) {
        uint256 playerItems = players[_user].items.length;

        if (playerItems == 0) return 0;

        for (uint256 i; i < playerItems; ++i) {
            damageModifier += players[_user].items[i].damageMultiplier;
        }
        damageModifier / DIVISOR;
    }

    function _isAlive(uint256 _bossId) internal view returns (bool) {
        return bosses[_bossId].hp > 0;
    }

    function _currentBoss() internal view returns (Boss storage) {
        return bosses[bosses.length - 1];
    }

    function _dealDamage(uint16 damage, Boss storage _boss) internal returns (uint16 hp) {
        if (damage >= _boss.hp) {
            _boss.hp = 0;
        } else {
            _boss.hp -= damage;
        }
        return _boss.hp;
    }
}
