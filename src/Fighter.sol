pragma solidity ^0.8.0;

import "solmate/auth/Owned.sol";

contract zkTextPG is Owned {
    struct Item {
        string name;
        uint96 price;
        uint8 damageMultiplier;
    }

    struct Boss {
        string name;
        uint96 hp;
        bool alive;
        uint64 balance;
    }

    mapping(address => uint256) public userDamageModifiers;
    mapping(uint32 => Item) public items;
    mapping(uint32 => Boss) public bosses;
    uint32 public itemCount;
    uint32 public bossCount;
    uint64 public constant ATTACK_FEE = 0.01 ether;

    event ItemCreated(uint256 indexed itemId, string name, uint256 price, uint256 damageMultiplier);
    event ItemPurchased(address indexed buyer, uint256 indexed itemId);
    event AttackPerformed(address indexed attacker, uint256 damage);
    event BosssKilled(address indexed attacker, uint256 damage);

    constructor() Owned(msg.sender) {
        bossCount++;
        bosses[bossCount] = Boss("Goblin", 100, true);
    }

    function createItem(string memory name, uint96 price, uint8 damageMultiplier) public onlyOwner {
        items[itemCount] = Item(name, price, damageMultiplier);
        emit ItemCreated(itemCount, name, price, damageMultiplier);
        itemCount++;
    }

    function purchaseItem(uint256 itemId) public {
        require(itemId < itemCount, "Invalid item ID");
        Item memory item = items[itemId];

        userDamageModifiers[msg.sender] = item.damageMultiplier;

        emit ItemPurchased(msg.sender, itemId);
    }

    function attack(uint256 payment) public {
        uint256 baseDamage = payment;
        uint256 userDamageModifier = userDamageModifiers[msg.sender];
        uint256 totalDamage = baseDamage * userDamageModifier;

        emit AttackPerformed(msg.sender, totalDamage);
    }
}
