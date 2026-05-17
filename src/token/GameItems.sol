// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {ERC1155URIStorage} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";

/// @title GameItems
/// @notice ERC1155 contract for in-game resources, equipment, and loot rewards.
/// @dev Uses role-based access control so crafting, loot, and rental modules can be granted minimal privileges.
contract GameItems is ERC1155, ERC1155Supply, ERC1155URIStorage, AccessControl {
    /// @notice Role allowed to mint items.
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @notice Role allowed to burn items.
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /// @notice Role allowed to update token and base URIs.
    bytes32 public constant URI_SETTER_ROLE = keccak256("URI_SETTER_ROLE");

    /// @notice Canonical item id for wood.
    uint256 public constant WOOD = 1;

    /// @notice Canonical item id for stone.
    uint256 public constant STONE = 2;

    /// @notice Canonical item id for iron.
    uint256 public constant IRON = 3;

    /// @notice Canonical item id for sword.
    uint256 public constant SWORD = 4;

    /// @notice Canonical item id for shield.
    uint256 public constant SHIELD = 5;

    /// @notice Canonical item id for rare chest.
    uint256 public constant RARE_CHEST = 6;

    /// @notice Canonical item id for legendary item.
    uint256 public constant LEGENDARY_ITEM = 7;

    /// @notice Emitted when a privileged minter creates a single item.
    event GameItemMinted(address indexed operator, address indexed to, uint256 indexed id, uint256 amount);

    /// @notice Emitted when a privileged minter creates multiple items.
    event GameItemsBatchMinted(address indexed operator, address indexed to, uint256[] ids, uint256[] amounts);

    /// @notice Emitted when a privileged burner destroys a single item.
    event GameItemBurned(address indexed operator, address indexed from, uint256 indexed id, uint256 amount);

    /// @notice Emitted when a privileged burner destroys multiple items.
    event GameItemsBatchBurned(address indexed operator, address indexed from, uint256[] ids, uint256[] amounts);

    /// @notice Emitted when the base URI is updated.
    event BaseURIUpdated(address indexed operator, string newBaseURI);

    /// @notice Emitted when a token-specific URI is updated.
    event TokenURIUpdated(address indexed operator, uint256 indexed id, string newTokenURI);

    /// @param admin Address that receives admin, mint, burn, and URI roles.
    /// @param baseURI Initial base URI used by the ERC1155 metadata mechanism.
    constructor(address admin, string memory baseURI) ERC1155(baseURI) {
        _setBaseURI(baseURI);
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(MINTER_ROLE, admin);
        _grantRole(BURNER_ROLE, admin);
        _grantRole(URI_SETTER_ROLE, admin);
    }

    /// @notice Mints a single item id to a recipient.
    /// @param to Recipient of the minted item.
    /// @param id Item id to mint.
    /// @param amount Amount of the item to mint.
    /// @param data Additional ERC1155 receiver hook data.
    function mint(address to, uint256 id, uint256 amount, bytes calldata data) external onlyRole(MINTER_ROLE) {
        _mint(to, id, amount, data);
        emit GameItemMinted(msg.sender, to, id, amount);
    }

    /// @notice Mints multiple item ids to a recipient.
    /// @param to Recipient of the minted items.
    /// @param ids Item ids to mint.
    /// @param amounts Amounts to mint for each id.
    /// @param data Additional ERC1155 receiver hook data.
    function mintBatch(address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data)
        external
        onlyRole(MINTER_ROLE)
    {
        _mintBatch(to, ids, amounts, data);
        emit GameItemsBatchMinted(msg.sender, to, ids, amounts);
    }

    /// @notice Burns a single item id from an account.
    /// @param from Address whose balance is reduced.
    /// @param id Item id to burn.
    /// @param amount Amount to burn.
    function burn(address from, uint256 id, uint256 amount) external onlyRole(BURNER_ROLE) {
        _burn(from, id, amount);
        emit GameItemBurned(msg.sender, from, id, amount);
    }

    /// @notice Burns multiple item ids from an account.
    /// @param from Address whose balances are reduced.
    /// @param ids Item ids to burn.
    /// @param amounts Amounts to burn for each id.
    function burnBatch(address from, uint256[] calldata ids, uint256[] calldata amounts)
        external
        onlyRole(BURNER_ROLE)
    {
        _burnBatch(from, ids, amounts);
        emit GameItemsBatchBurned(msg.sender, from, ids, amounts);
    }

    /// @notice Sets a token-specific URI suffix or full URI.
    /// @param id Item id whose URI is being updated.
    /// @param tokenURI New token-specific URI value.
    function setTokenURI(uint256 id, string calldata tokenURI) external onlyRole(URI_SETTER_ROLE) {
        _setURI(id, tokenURI);
        emit TokenURIUpdated(msg.sender, id, tokenURI);
    }

    /// @notice Sets the base URI prefix used by token-specific URIs.
    /// @param baseURI New base URI value.
    function setBaseURI(string calldata baseURI) external onlyRole(URI_SETTER_ROLE) {
        _setBaseURI(baseURI);
        emit BaseURIUpdated(msg.sender, baseURI);
    }

    /// @inheritdoc ERC1155
    function uri(uint256 tokenId) public view override(ERC1155, ERC1155URIStorage) returns (string memory) {
        return super.uri(tokenId);
    }

    /// @inheritdoc AccessControl
    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }
}
