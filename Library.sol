// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Тестовое задание для Zelenka.guru от Tamashii

// Дополнительный контракт, который обрабатывает все, что касается овнерки
contract Ownable {
    // Ивент передачи владения контрактом
    event OwnershipTransferred(address indexed user, address indexed newOwner);

    // Кастомные ошибки
    error Unauthorized();
    error InvalidOwner();

    // Переменная хранит адрес владельца
    address public owner;

    // Модификатор, который разрешает использовать функцию только владельцу контракта
    modifier onlyOwner() virtual {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    // Функция, которая вызывается во время деплоя контракта, вызывается только один раз
    constructor() {
        owner = msg.sender;

        emit OwnershipTransferred(address(0), owner);
    }

    // Функция для владельца, позволяющая передать владение контрактом другому адресу
        function transferOwnership(address _owner) public virtual onlyOwner {
        if (_owner == address(0)) revert InvalidOwner();
        owner = _owner;

        emit OwnershipTransferred(msg.sender, _owner);
    }

    // Функция для владельца, позволяющая передать владение контрактом нулевому адресу (полный отказ от овнерки навсегда)
    function revokeOwnership() public virtual onlyOwner {
        owner = address(0);

        emit OwnershipTransferred(msg.sender, address(0));
    }
}

// Основной контракт
contract Lib is Ownable {

    // Структура книги (айди и цена)
    struct Book {
        uint id;
        uint price;
    }

    // Переменные
    mapping (uint => uint) public bookPrice; // Переменная соответсвия, хранит цену определенной книги
    mapping (uint => address) public ownerOf; // Переменная соответсвия, хранит владельца определенной книги
    mapping (address => bool) public alreadyHave; // переменная соответсвия, хранит bool покупал человек книгу или нет
    address lastUser; // Внутренняя переменная, которая хранит последнего пользователя функции takeTheBook, потом этот адрес используется для создания хеша (повышает рандомизацию* цены книги)
    uint public minted; // Количество созданных книг 
    uint public amountPurchasedBooks; // Количество проданных книг

    // Функция, которая вызывается только один раз при деплое контрактом, создает n количество книг с рандомными ценами
    constructor (uint amountBooks) {
        createBooksWithRandomPrices(amountBooks);
    }

    // Функция позволяет получить список книг и их цену
    function getAllPrices() external view returns (string memory) {
        string memory result = "";
        for (uint i = 0; i < minted; i++) {
            result = string(abi.encodePacked(result, uintToString(i), ": ", uintToString(bookPrice[i]), "\n\n"));
        }
    return result;
    }

    // Функция для владельца, позволяющая создать какое-то количество книг с рандомной ценой*
    function createBooksWithRandomPrices(uint amount) public onlyOwner {
        for (uint i; i < amount; i++) {
            uint price = (uint(keccak256(abi.encodePacked(block.number, minted, block.timestamp, lastUser))) % 100) * 10**15;
            bookPrice[minted] = price;
            minted++;
        }
    }

    // Функция для владельца, позволяющая создать какое то количество новых книг с одинаковой, выбранной ценой
    function createBookWithFixPrice(uint amount, uint price) external onlyOwner {
        for (uint i; i < amount; i++) {
            bookPrice[minted] = price;
            minted++;
        }
    }

    // Функция позволяющая купить книгу
    function takeTheBook(uint id) external payable {
        uint price = bookPrice[id];
        uint amount = msg.value;
        address user = msg.sender;

        require(alreadyHave[user] == false, "Already have");
        require(ownerOf[id] == address(0), "this book has already been purchased.");
        require(amount >= price, "The amount sent must equal or exceed the cost of the book");
        ownerOf[id] = user;
        alreadyHave[user] = true;
        if (amount > price) {
            uint residue = amount - price;
            (bool success, ) = user.call{value: residue}("");
            require(success);
        }
        lastUser = user;
        amountPurchasedBooks++;
        (bool success1, ) = owner.call{value: price}("");
        require(success1);
    }

    // Вспомогательная внутренняя функция, которая переводит числовое значение в текстовое (да, в солидити все так сложно)
    function uintToString(uint v) internal pure returns (string memory) {
        uint maxlength = 100;
        bytes memory reversed = new bytes(maxlength);
        uint i = 0;
        while (v != 0) {
            uint remainder = v % 10;
            v = v / 10;
            reversed[i++] = bytes1(uint8(48 + remainder));
        }
        bytes memory s = new bytes(i);
        for (uint j = 0; j < i; j++) {
            s[j] = reversed[i - j - 1];
        }
        return string(s);
    }
}

/*

*

В солидити нет рандома, можно сделать псевдорандом, который почти невозможно просчитать

uint price = (uint(keccak256(abi.encodePacked(block.number, minted, block.timestamp, lastUser))) % 100) * 10**15;

Создается хеш от строки(номер текущего блока + количество заминтченных книг + время создания текущего блока + адреса последнего пользователя функцией

После этот хеш преобразуется в число и берется модуль, получается число от 0 до 99, после оно умножается на 10**15, переводя число в Wei

*/