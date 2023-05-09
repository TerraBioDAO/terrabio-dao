// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "openzeppelin-contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/access/Ownable.sol";
import "openzeppelin-contracts/utils/Counters.sol";
import "openzeppelin-contracts/utils/Address.sol";

contract TerraBioLabel is ERC721URIStorage, Ownable {
    using Address for address;
    using Counters for Counters.Counter;

    error NotAttributed(uint256 labelId);
    error StillValid(uint256 labelId, uint256 status);
    error CannotRenew(uint256 labelId, uint256 status);
    error NoMetadataUpdate(uint256 labelId);

    enum LabelStatus {
        NotAttributed,
        Active,
        Outpassed,
        Invalid
    }

    struct Label {
        uint64 expiration;
        LabelStatus status;
    }

    uint256 public constant LABEL_EXPIRATION = 60 * 60 * 24 * 366;

    Counters.Counter private _lastLabelId;
    mapping(uint256 => Label) private _labels;

    constructor(
        string memory name_,
        string memory symbol_,
        address daoAddress
    ) ERC721(name_, symbol_) {
        _transferOwnership(daoAddress);
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                              EXTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function mintLabel(address recipient, string memory metadataURI) public onlyOwner {
        _lastLabelId.increment();
        uint256 labelId = _lastLabelId.current();

        _mint(recipient, labelId);
        _setTokenURI(labelId, metadataURI);
        _labels[labelId] = Label({
            expiration: uint64(block.timestamp + LABEL_EXPIRATION),
            status: LabelStatus.Active
        });
    }

    function burnLabel(uint256 labelId) external onlyOwner {
        LabelStatus status = labelStatus(labelId);
        if (status != LabelStatus.Invalid) revert StillValid(labelId, uint256(status));

        delete _labels[labelId];
        _burn(labelId);
    }

    /**
     * @dev {user} can be changed at this moment
     *
     * The label URI is forced to change when it's renewed, a comparaison
     * of hash(keccak256) is done with old and new URI.
     */
    function renewLabel(
        uint256 labelId,
        address recipient,
        string memory updatedURI
    ) external onlyOwner {
        LabelStatus status = labelStatus(labelId);
        if (status != LabelStatus.Outpassed) revert CannotRenew(labelId, uint256(status));

        // URIs checked
        bytes32 lastURI = keccak256(bytes(tokenURI(labelId)));
        if (lastURI == keccak256(bytes(updatedURI))) revert NoMetadataUpdate(labelId);

        // owner can change
        address oldRecipient = ownerOf(labelId);
        if (recipient != oldRecipient) {
            _transfer(oldRecipient, recipient, labelId);
        }

        _setTokenURI(labelId, updatedURI);
        _labels[labelId] = Label({
            expiration: uint64(block.timestamp + LABEL_EXPIRATION),
            status: LabelStatus.Active
        });
    }

    function migrateLabel(uint256 labelId, address newRecipient) external onlyOwner {
        if (labelStatus(labelId) == LabelStatus.NotAttributed) revert NotAttributed(labelId);
        _transfer(ownerOf(labelId), newRecipient, labelId);
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                              GETTERS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    function labelExpires(uint256 tokenId) external view returns (uint256) {
        return _labels[tokenId].expiration;
    }

    /**
     * @dev Return the status of the label depends on the expiration
     *
     * TODO return the status if this latter is arbitrary setted
     */
    function labelStatus(uint256 labelId) public view returns (LabelStatus) {
        Label memory label = _labels[labelId];
        uint256 timestamp = block.timestamp;

        if (label.status == LabelStatus.NotAttributed) {
            return LabelStatus.NotAttributed;
        }

        // here return others status (Paused, Suspended, ...)

        if (timestamp >= label.expiration * 2) {
            return LabelStatus.Invalid;
        } else if (timestamp >= label.expiration) {
            return LabelStatus.Outpassed;
        } else {
            return LabelStatus.Active;
        }
    }

    /*////////////////////////////////////////////////////////////////////////////////////////////////
                                            INTERNAL FUNCTIONS
    ////////////////////////////////////////////////////////////////////////////////////////////////*/

    /// @dev implement modifier here to prevent transfers
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal override onlyOwner {}
}
