pragma solidity 0.8.17;
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
contract MockNFT is ERC721 {
    constructor() ERC721("a", "a") {
        _mint(msg.sender, 0);
        _mint(msg.sender, 1);
        _mint(msg.sender, 2);
        _mint(msg.sender, 3);
        _mint(msg.sender, 4);
        _mint(msg.sender, 5);
        _mint(msg.sender, 6);
    }
}