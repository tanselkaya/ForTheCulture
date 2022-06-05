// SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "@openzeppelin/contracts@4.6.0/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts@4.6.0/access/Ownable.sol";
import "@openzeppelin/contracts@4.6.0/utils/Counters.sol";
import "@openzeppelin/contracts@4.6.0/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts@4.6.0/security/Pausable.sol";

contract ForTheCulture is ERC721, Ownable, Pausable {

  using Strings for uint256;
  using Counters for Counters.Counter;

  Counters.Counter private supply;
  mapping (address => uint) nftCounts;

  bytes32 merkleRoot = 0x02d2116e529b013a2a97c380516706c46e0bf071f96cae1702ec5f41034a4d4b;
  
  string public uriPrefix = "https://nftftc.s3.eu-west-1.amazonaws.com/test_metadata/";
  string public uriSuffix = ".json";
  
  uint256 constant fee = 0.01 ether;
  uint256 constant maxSupply = 6969;

  uint256 constant mintAmount = 1;
  uint256 constant maxMintAmountPerTx = 1;
  uint256 constant maxMintAmountPerWallet = 1;

  bool public isWhitelistMintActive = false;

  event Received(address, uint);

  receive() external payable {
    emit Received(msg.sender, msg.value);
  }
  
  constructor() ERC721("For the Culture", "FTC") {}

  modifier onlyOrigin () {
    require(msg.sender == tx.origin, "Contract calls are not allowed");
    _;
  }

  function pause() public onlyOwner {
        _pause();
  }

  function unpause() public onlyOwner {
        _unpause();
  }

  function whitelistMint(bytes32[] calldata proof) external payable onlyOrigin {
    
    uint256 balance = address(this).balance;
    
    require(isWhitelistMintActive, "Whitelist mint is not active!");
    require(balance >= fee, "Insufficient funds!");
    require(nftCounts[msg.sender] + mintAmount <= maxMintAmountPerWallet, "Exceeds mint amount per wallet!");
    require(supply.current() + mintAmount <= maxSupply, "Max supply exceeded!");
    require(MerkleProof.verify(proof, merkleRoot, keccak256(abi.encodePacked(msg.sender))), "You are not whitelisted!");

    _withdraw(payable(msg.sender), fee);
    nftCounts[msg.sender] += mintAmount;
    supply.increment();
    _safeMint(msg.sender, supply.current());
  }
  
  function ownerMint(uint256 _mintAmount, address _receiver) external onlyOwner {

    require(supply.current() + _mintAmount <= maxSupply, "Max supply exceeded!");
    
    for (uint256 i = 0; i < _mintAmount; i++) {
      supply.increment();
      _safeMint(_receiver, supply.current());
    }
  }

  function tokenURI(uint256 _tokenId) public view virtual override returns (string memory) {
    require(_exists(_tokenId), "Non-existent token given!");

    string memory currentBaseURI = _baseURI();
    return bytes(currentBaseURI).length > 0
        ? string(abi.encodePacked(currentBaseURI, _tokenId.toString(), uriSuffix))
        : "";
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return uriPrefix;
  }

  function totalSupply() external view returns (uint256) {
    return supply.current();
  }

  function setUriPrefix(string memory _uriPrefix) external onlyOwner {
    uriPrefix = _uriPrefix;
  }

  function setUriSuffix(string memory _uriSuffix) external onlyOwner {
    uriSuffix = _uriSuffix;
  }

  function setIsWhitelistMintActive(bool _state) external onlyOwner {
    isWhitelistMintActive = _state;
  }

  function setMerkleRoot(bytes32 _root) external onlyOwner {
    merkleRoot = _root;
  }

  function withdrawAll() external onlyOwner {
    uint256 balance = address(this).balance;
    require(balance > 0);
      
    _withdraw(owner(), address(this).balance);
  }

  function _withdraw(address _address, uint256 _amount) private {
    (bool success, ) = _address.call{value: _amount}("");
    require(success, "Transfer failed.");
  }

  function _beforeTokenTransfer(address from, address to, uint256 tokenId) internal whenNotPaused override {
    super._beforeTokenTransfer(from, to, tokenId);
  } 
}
