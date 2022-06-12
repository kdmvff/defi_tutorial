pragma solidity ^0.8.0;

// Interface
// import { IDropERC1155 } from "../interfaces/drop/IDropERC1155.sol";
import { IDropERC1155 } from "../mainnetContracts/IDropERC1155.sol";

// Token
// import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import {ERC1155Upgradeable} from "../mainnetContracts/ERC1155Upgradeable.sol";
// Access Control + security
// import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
import {AccessControlEnumerableUpgradeable} from "../mainnetContracts/AccessControlEnumerableUpgradeable.sol";

// import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "../mainnetContracts/ReentrancyGuardUpgradeable.sol";

// Meta transactions
// import "../openzeppelin-presets/metatx/ERC2771ContextUpgradeable.sol";
import {ERC2771ContextUpgradeable} from "../mainnetContracts/ERC2771ContextUpgradeable.sol";

// Utils
// import "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {MulticallUpgradeable} from "../mainnetContracts/MulticallUpgradeable.sol";

// import "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import {StringsUpgradeable} from "../mainnetContracts/StringsUpgradeable.sol";

import {IERC165Upgradeable} from "../mainnetContracts/IERC165Upgradeable.sol";

import "../mainnetContracts/ContextUpgradeable.sol";

import "../mainnetContracts/CurrencyTransferLib.sol";
import "../mainnetContracts/FeeType.sol";
import "../mainnetContracts/MerkleProof.sol";

import "../mainnetContracts/Initializable.sol";

// Helper interfaces
import { IWETH } from "../mainnetContracts/IWETH.sol";

// import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import {IERC20Upgradeable} from "../mainnetContracts/IERC20Upgradeable.sol";

// import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";

import {IERC2981Upgradeable} from "../mainnetContracts/IERC2981Upgradeable.sol";

// import "@openzeppelin/contracts-upgradeable/utils/structs/BitMapsUpgradeable.sol";
import {BitMapsUpgradeable} from "../mainnetContracts/BitMapsUpgradeable.sol";
// Thirdweb top-level
import "../mainnetContracts/ITWFee.sol";

contract DropERC1155 is
    Initializable,
    ReentrancyGuardUpgradeable,
    ERC2771ContextUpgradeable,
    MulticallUpgradeable,
    AccessControlEnumerableUpgradeable,
    ERC1155Upgradeable,
    IDropERC1155
{
    using BitMapsUpgradeable for BitMapsUpgradeable.BitMap;
    using StringsUpgradeable for uint256;

    bytes32 private constant MODULE_TYPE = bytes32("DropERC1155");
    uint256 private constant VERSION = 1;

    // Token name
    string public name;

    // Token symbol
    string public symbol;

    /// @dev Only TRANSFER_ROLE holders can participate in transfers, when transfers are restricted.
    bytes32 private constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");

    /// @dev Only MINTER_ROLE holders can lazy mint NFTs.
    bytes32 private constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @dev Max bps in the thirdweb system
    uint256 private constant MAX_BPS = 10_000;

    /// @dev The address interpreted as native token of the chain.
    address private constant NATIVE_TOKEN = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    /// @dev The thirdweb contract with fee related information.
    ITWFee public immutable thirdwebFee;

    /// @dev Owner of the contract (purpose: OpenSea compatibility, etc.)
    address private _owner;

    // @dev The next token ID of the NFT to "lazy mint".
    uint256 public nextTokenIdToMint;

    /// @dev The adress that receives all primary sales value.
    address public primarySaleRecipient;

    /// @dev The adress that receives all primary sales value.
    address private platformFeeRecipient;

    /// @dev The recipient of who gets the royalty.
    address private royaltyRecipient;

    /// @dev The percentage of royalty how much royalty in basis points.
    uint128 private royaltyBps;

    /// @dev The % of primary sales collected by the contract as fees.
    uint128 private platformFeeBps;

    address[] private trustedForwarders;

    /// @dev Contract level metadata.
    string public contractURI;

    uint256[] private baseURIIndices;

    /// @dev End token Id => URI that overrides `baseURI + tokenId` convention.
    mapping(uint256 => string) private baseURI;

    /// @dev Token ID => total circulating supply of tokens with that ID.
    mapping(uint256 => uint256) public totalSupply;

    /// @dev Token ID => maximum allowed total circulating supply of tokens with that ID.
    mapping(uint256 => uint256) public maxTotalSupply;

    /// @dev Token ID => public claim conditions for tokens with that ID.
    mapping(uint256 => ClaimConditionList) public claimCondition;

    /// @dev Token ID => the address of the recipient of primary sales.
    mapping(uint256 => address) public saleRecipient;

    /// @dev Token ID => royalty recipient and bps for token
    mapping(uint256 => RoyaltyInfo) private royaltyInfoForToken;

    /// @dev Token ID => claimer wallet address => number of claim.
    mapping(uint256 => mapping(address => uint256)) public walletClaimCount;

    /// @dev Token ID => max claim limit per wallet.
    mapping(uint256 => uint256) public maxWalletClaimCount;

    constructor(address _thirdwebFee) initializer {
        thirdwebFee = ITWFee(_thirdwebFee);
    }

    /// @dev Initiliazes the contract, like a constructor.
    function initialize(
        //address _defaultAdmin,
        //string memory _name,
        //string memory _symbol,
        //string memory _contractURI,
        //address[] memory _trustedForwarders,
        //address _saleRecipient,
        //address _royaltyRecipient,
        //uint128 _royaltyBps,
        //uint128 _platformFeeBps,
        //address _platformFeeRecipient
    ) external initializer {
        trustedForwarders.push(0x8E6a9e6F141BF9bd5A9a4318aD5458D1ad312939);
        // Initialize inherited contracts, most base-like -> most derived.
        __ReentrancyGuard_init();
        __ERC2771Context_init_unchained(trustedForwarders);
        __ERC1155_init_unchained("");

        // Initialize this contract's state.
        //name = _name;
        name = "Founders Club";
        //symbol = _symbol;
        symbol = "PAWTHFOUNDER";
        //royaltyRecipient = _royaltyRecipient;
        royaltyRecipient = 0x8E6a9e6F141BF9bd5A9a4318aD5458D1ad312939;
        //royaltyBps = _royaltyBps;
        royaltyBps = 250;
        //platformFeeRecipient = _platformFeeRecipient;
        platformFeeRecipient = 0x8E6a9e6F141BF9bd5A9a4318aD5458D1ad312939;
        //primarySaleRecipient = _saleRecipient;
        primarySaleRecipient = 0x8E6a9e6F141BF9bd5A9a4318aD5458D1ad312939;
        contractURI = "ipfs://QmfF1YwwSvV5veD1MysGBAaDds6nBgTUqs3r6hCUsb4XmR/0";
        platformFeeBps = 0;

        _owner = 0x8E6a9e6F141BF9bd5A9a4318aD5458D1ad312939;
        _setupRole(DEFAULT_ADMIN_ROLE, 0x8E6a9e6F141BF9bd5A9a4318aD5458D1ad312939);
        _setupRole(MINTER_ROLE, 0x8E6a9e6F141BF9bd5A9a4318aD5458D1ad312939);
        _setupRole(TRANSFER_ROLE, 0x8E6a9e6F141BF9bd5A9a4318aD5458D1ad312939);
        _setupRole(TRANSFER_ROLE, address(0));
    }

    ///     =====   Public functions  =====

    /// @dev Returns the module type of the contract.
    function contractType() external pure returns (bytes32) {
        return MODULE_TYPE;
    }

    /// @dev Returns the version of the contract.
    function contractVersion() external pure returns (uint8) {
        return uint8(VERSION);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns (address) {
        return hasRole(DEFAULT_ADMIN_ROLE, _owner) ? _owner : address(0);
    }

    /// @dev Returns the URI for a given tokenId.
    function uri(uint256 _tokenId) public view override returns (string memory _tokenURI) {
        for (uint256 i = 0; i < baseURIIndices.length; i += 1) {
            if (_tokenId < baseURIIndices[i]) {
                return string(abi.encodePacked(baseURI[baseURIIndices[i]], _tokenId.toString()));
            }
        }

        return "";
    }

    /// @dev At any given moment, returns the uid for the active mint condition for a given tokenId.
    function getActiveClaimConditionId(uint256 _tokenId) public view returns (uint256) {
        ClaimConditionList storage conditionList = claimCondition[_tokenId];
        for (uint256 i = conditionList.currentStartId + conditionList.count; i > conditionList.currentStartId; i--) {
            if (block.timestamp >= conditionList.phases[i - 1].startTimestamp) {
                return i - 1;
            }
        }

        revert("no active mint condition.");
    }

    ///     =====   External functions  =====

    /// @dev See EIP-2981
    function royaltyInfo(uint256 tokenId, uint256 salePrice)
        external
        view
        virtual
        returns (address receiver, uint256 royaltyAmount)
    {
        (address recipient, uint256 bps) = getRoyaltyInfoForToken(tokenId);
        receiver = recipient;
        royaltyAmount = (salePrice * bps) / MAX_BPS;
    }

    /**
     *  @dev Lets an account with `MINTER_ROLE` mint tokens of ID from `nextTokenIdToMint`
     *       to `nextTokenIdToMint + _amount - 1`. The URIs for these tokenIds is baseURI + `${tokenId}`.
     */
    function lazyMint(uint256 _amount, string calldata _baseURIForTokens) external onlyRole(MINTER_ROLE) {
        uint256 startId = nextTokenIdToMint;
        uint256 baseURIIndex = startId + _amount;

        nextTokenIdToMint = baseURIIndex;
        baseURI[baseURIIndex] = _baseURIForTokens;
        baseURIIndices.push(baseURIIndex);

        emit TokensLazyMinted(startId, startId + _amount - 1, _baseURIForTokens);
    }

    /// @dev Lets an account claim a given quantity of tokens, of a single tokenId.
    function claim(
        address _receiver,
        uint256 _tokenId,
        uint256 _quantity,
        address _currency,
        uint256 _pricePerToken,
        bytes32[] calldata _proofs,
        uint256 _proofMaxQuantityPerTransaction
    ) external payable nonReentrant {
        // Get the active claim condition index.
        uint256 activeConditionId = getActiveClaimConditionId(_tokenId);

        // Verify claim validity. If not valid, revert.
        verifyClaim(activeConditionId, _msgSender(), _tokenId, _quantity, _currency, _pricePerToken);

        (bool validMerkleProof, uint256 merkleProofIndex) = verifyClaimMerkleProof(
            activeConditionId,
            _msgSender(),
            _tokenId,
            _quantity,
            _proofs,
            _proofMaxQuantityPerTransaction
        );

        // if the current claim condition and has a merkle root and the provided proof is valid
        // if validMerkleProof is false, it means that claim condition does not have a merkle root
        // if invalid proofs are provided, the verifyClaimMerkleProof would revert.
        if (validMerkleProof && _proofMaxQuantityPerTransaction > 0) {
            claimCondition[_tokenId].limitMerkleProofClaim[activeConditionId].set(merkleProofIndex);
        }

        // If there's a price, collect price.
        collectClaimPrice(_quantity, _currency, _pricePerToken, _tokenId);

        // Mint the relevant tokens to claimer.
        transferClaimedTokens(_receiver, activeConditionId, _tokenId, _quantity);

        emit TokensClaimed(activeConditionId, _tokenId, _msgSender(), _receiver, _quantity);
    }

    /// @dev Lets a module admin set mint conditions.
    function setClaimConditions(
        uint256 _tokenId,
        ClaimCondition[] calldata _phases,
        bool _resetLimitRestriction
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        ClaimConditionList storage condition = claimCondition[_tokenId];
        uint256 existingStartIndex = condition.currentStartId;
        uint256 existingPhaseCount = condition.count;

        // if it's to reset restriction, all new claim phases would start at the end of the existing batch.
        // otherwise, the new claim phases would override the existing phases and limits from the existing start index
        uint256 newStartIndex = existingStartIndex;
        if (_resetLimitRestriction) {
            newStartIndex = existingStartIndex + existingPhaseCount;
        }

        uint256 lastConditionStartTimestamp;
        for (uint256 i = 0; i < _phases.length; i++) {
            // only compare the 2nd++ phase start timestamp to the previous start timestamp
            require(
                i == 0 || lastConditionStartTimestamp < _phases[i].startTimestamp,
                "startTimestamp must be in ascending order."
            );

            condition.phases[newStartIndex + i] = _phases[i];
            condition.phases[newStartIndex + i].supplyClaimed = 0;

            lastConditionStartTimestamp = _phases[i].startTimestamp;
        }

        // freeing up claim phases and claim limit (gas refund)
        // if we are resetting restriction, then we'd clean up previous batch map up to the new start index.
        // if we are not, it means that we're updating, then we'd only clean up unused claim phases and limits.
        // not deleting last claim timestamp maps because we don't have access to addresses. it's fine to not clean it up
        // because the currentStartId decides which claim timestamp map to use.
        if (_resetLimitRestriction) {
            for (uint256 i = existingStartIndex; i < newStartIndex; i++) {
                delete condition.phases[i];
                delete condition.limitMerkleProofClaim[i];
            }
        } else {
            // in the update scenario:
            // if there are more old (existing) phases than the newly set ones, delete all the remaining
            // unused phases and limits.
            // if there are more new phases than old phases, then there's no excess claim condition to clean up.
            if (existingPhaseCount > _phases.length) {
                for (uint256 i = _phases.length; i < existingPhaseCount; i++) {
                    delete condition.phases[newStartIndex + i];
                    delete condition.limitMerkleProofClaim[newStartIndex + i];
                }
            }
        }

        condition.count = _phases.length;
        condition.currentStartId = newStartIndex;

        emit ClaimConditionsUpdated(_tokenId, _phases);
    }

    //      =====   Setter functions  =====
    /// @dev Lets a module admin set a claim limit on a wallet.
    function setWalletClaimCount(
        uint256 _tokenId,
        address _claimer,
        uint256 _count
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        walletClaimCount[_tokenId][_claimer] = _count;
        emit WalletClaimCountUpdated(_tokenId, _claimer, _count);
    }

    /// @dev Lets a module admin set a maximum number of claim per wallet.
    function setMaxWalletClaimCount(uint256 _tokenId, uint256 _count) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxWalletClaimCount[_tokenId] = _count;
        emit MaxWalletClaimCountUpdated(_tokenId, _count);
    }

    /// @dev Lets a module admin set a max total supply for token.
    function setMaxTotalSupply(uint256 _tokenId, uint256 _maxTotalSupply) external onlyRole(DEFAULT_ADMIN_ROLE) {
        maxTotalSupply[_tokenId] = _maxTotalSupply;
        emit MaxTotalSupplyUpdated(_tokenId, _maxTotalSupply);
    }

    /// @dev Lets a module admin set the default recipient of all primary sales.
    function setPrimarySaleRecipient(address _saleRecipient) external onlyRole(DEFAULT_ADMIN_ROLE) {
        primarySaleRecipient = _saleRecipient;
        emit PrimarySaleRecipientUpdated(_saleRecipient);
    }

    /// @dev Lets a module admin update the royalty bps and recipient.
    function setDefaultRoyaltyInfo(address _royaltyRecipient, uint256 _royaltyBps)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_royaltyBps <= MAX_BPS, "exceed royalty bps");

        royaltyRecipient = _royaltyRecipient;
        royaltyBps = uint128(_royaltyBps);

        emit DefaultRoyalty(_royaltyRecipient, _royaltyBps);
    }

    /// @dev Lets a module admin set the royalty recipient for a particular token Id.
    function setRoyaltyInfoForToken(
        uint256 _tokenId,
        address _recipient,
        uint256 _bps
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_bps <= MAX_BPS, "exceed royalty bps");

        royaltyInfoForToken[_tokenId] = RoyaltyInfo({ recipient: _recipient, bps: _bps });

        emit RoyaltyForToken(_tokenId, _recipient, _bps);
    }

    /// @dev Lets a module admin update the fees on primary sales.
    function setPlatformFeeInfo(address _platformFeeRecipient, uint256 _platformFeeBps)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(_platformFeeBps <= MAX_BPS, "bps <= 10000.");

        platformFeeBps = uint64(_platformFeeBps);
        platformFeeRecipient = _platformFeeRecipient;

        emit PlatformFeeInfoUpdated(_platformFeeRecipient, _platformFeeBps);
    }

    /// @dev Lets a module admin set a new owner for the contract. The new owner must be a module admin.
    function setOwner(address _newOwner) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(hasRole(DEFAULT_ADMIN_ROLE, _newOwner), "new owner not module admin.");
        emit OwnerUpdated(_owner, _newOwner);
        _owner = _newOwner;
    }

    /// @dev Lets a module admin set the URI for contract-level metadata.
    function setContractURI(string calldata _uri) external onlyRole(DEFAULT_ADMIN_ROLE) {
        contractURI = _uri;
    }

    //      =====   Getter functions  =====

    /// @dev Returns the platform fee bps and recipient.
    function getPlatformFeeInfo() external view returns (address, uint16) {
        return (platformFeeRecipient, uint16(platformFeeBps));
    }

    /// @dev Returns the platform fee bps and recipient.
    function getDefaultRoyaltyInfo() external view returns (address, uint16) {
        return (royaltyRecipient, uint16(royaltyBps));
    }

    /// @dev Returns the royalty recipient for a particular token Id.
    function getRoyaltyInfoForToken(uint256 _tokenId) public view returns (address, uint16) {
        RoyaltyInfo memory royaltyForToken = royaltyInfoForToken[_tokenId];

        return
            royaltyForToken.recipient == address(0)
                ? (royaltyRecipient, uint16(royaltyBps))
                : (royaltyForToken.recipient, uint16(royaltyForToken.bps));
    }

    /// @dev Returns the timestamp for next available claim for a claimer address
    function getClaimTimestamp(
        uint256 _tokenId,
        uint256 _conditionId,
        address _claimer
    ) public view returns (uint256 lastClaimTimestamp, uint256 nextValidClaimTimestamp) {
        lastClaimTimestamp = claimCondition[_tokenId].limitLastClaimTimestamp[_conditionId][_claimer];

        unchecked {
            nextValidClaimTimestamp =
                lastClaimTimestamp +
                claimCondition[_tokenId].phases[_conditionId].waitTimeInSecondsBetweenClaims;

            if (nextValidClaimTimestamp < lastClaimTimestamp) {
                nextValidClaimTimestamp = type(uint256).max;
            }
        }
    }

    /// @dev Returns the claim condition for a given tokenId for the given condition id.
    function getClaimConditionById(uint256 _tokenId, uint256 _conditionId)
        external
        view
        returns (ClaimCondition memory condition)
    {
        condition = claimCondition[_tokenId].phases[_conditionId];
    }

    //      =====   Internal functions  =====

    /// @dev Checks whether a request to claim tokens obeys the active mint condition.
    function verifyClaim(
        uint256 _conditionId,
        address _claimer,
        uint256 _tokenId,
        uint256 _quantity,
        address _currency,
        uint256 _pricePerToken
    ) public view {
        ClaimCondition memory currentClaimPhase = claimCondition[_tokenId].phases[_conditionId];

        require(
            _currency == currentClaimPhase.currency && _pricePerToken == currentClaimPhase.pricePerToken,
            "invalid currency or price specified."
        );
        require(
            _quantity > 0 && _quantity <= currentClaimPhase.quantityLimitPerTransaction,
            "invalid quantity claimed."
        );
        require(
            currentClaimPhase.supplyClaimed + _quantity <= currentClaimPhase.maxClaimableSupply,
            "exceed max mint supply."
        );
        require(
            maxTotalSupply[_tokenId] == 0 || totalSupply[_tokenId] + _quantity <= maxTotalSupply[_tokenId],
            "exceed max total supply"
        );
        require(
            maxWalletClaimCount[_tokenId] == 0 ||
                walletClaimCount[_tokenId][_claimer] + _quantity <= maxWalletClaimCount[_tokenId],
            "exceed claim limit for wallet"
        );

        (uint256 lastClaimTimestamp, uint256 nextValidClaimTimestamp) = getClaimTimestamp(
            _tokenId,
            _conditionId,
            _claimer
        );
        require(lastClaimTimestamp == 0 || block.timestamp >= nextValidClaimTimestamp, "cannot claim yet.");
    }

    function verifyClaimMerkleProof(
        uint256 _conditionId,
        address _claimer,
        uint256 _tokenId,
        uint256 _quantity,
        bytes32[] calldata _proofs,
        uint256 _proofMaxQuantityPerTransaction
    ) public view returns (bool validMerkleProof, uint256 merkleProofIndex) {
        ClaimCondition memory currentClaimPhase = claimCondition[_tokenId].phases[_conditionId];

        if (currentClaimPhase.merkleRoot != bytes32(0)) {
            (validMerkleProof, merkleProofIndex) = MerkleProof.verify(
                _proofs,
                currentClaimPhase.merkleRoot,
                keccak256(abi.encodePacked(_claimer, _proofMaxQuantityPerTransaction))
            );
            require(validMerkleProof, "not in whitelist.");
            require(
                !claimCondition[_tokenId].limitMerkleProofClaim[_conditionId].get(merkleProofIndex),
                "proof claimed."
            );
            require(
                _proofMaxQuantityPerTransaction == 0 || _quantity <= _proofMaxQuantityPerTransaction,
                "invalid quantity proof."
            );
        }
    }

    /// @dev Collects and distributes the primary sale value of tokens being claimed.
    function collectClaimPrice(
        uint256 _quantityToClaim,
        address _currency,
        uint256 _pricePerToken,
        uint256 _tokenId
    ) internal {
        if (_pricePerToken == 0) {
            return;
        }

        uint256 totalPrice = _quantityToClaim * _pricePerToken;
        uint256 platformFees = (totalPrice * platformFeeBps) / MAX_BPS;
        (address twFeeRecipient, uint256 twFeeBps) = thirdwebFee.getFeeInfo(address(this), FeeType.PRIMARY_SALE);
        uint256 twFee = (totalPrice * twFeeBps) / MAX_BPS;

        if (_currency == NATIVE_TOKEN) {
            require(msg.value == totalPrice, "must send total price.");
        }

        address recipient = saleRecipient[_tokenId] == address(0) ? primarySaleRecipient : saleRecipient[_tokenId];
        CurrencyTransferLib.transferCurrency(_currency, _msgSender(), platformFeeRecipient, platformFees);
        CurrencyTransferLib.transferCurrency(_currency, _msgSender(), twFeeRecipient, twFee);
        CurrencyTransferLib.transferCurrency(_currency, _msgSender(), recipient, totalPrice - platformFees - twFee);
    }

    /// @dev Transfers the tokens being claimed.
    function transferClaimedTokens(
        address _to,
        uint256 _conditionId,
        uint256 _tokenId,
        uint256 _quantityBeingClaimed
    ) internal {
        // Update the supply minted under mint condition.
        claimCondition[_tokenId].phases[_conditionId].supplyClaimed += _quantityBeingClaimed;

        // if transfer claimed tokens is called when to != msg.sender, it'd use msg.sender's limits.
        // behavior would be similar to msg.sender mint for itself, then transfer to `to`.
        claimCondition[_tokenId].limitLastClaimTimestamp[_conditionId][_msgSender()] = block.timestamp;

        walletClaimCount[_tokenId][_msgSender()] += _quantityBeingClaimed;

        _mint(_to, _tokenId, _quantityBeingClaimed, "");
    }

    ///     =====   ERC 1155 functions  =====

    /// @dev Lets a token owner burn the tokens they own (i.e. destroy for good)
    function burn(
        address account,
        uint256 id,
        uint256 value
    ) public virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not owner nor approved."
        );

        _burn(account, id, value);
    }

    /// @dev Lets a token owner burn multiple tokens they own at once (i.e. destroy for good)
    function burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory values
    ) public virtual {
        require(
            account == _msgSender() || isApprovedForAll(account, _msgSender()),
            "ERC1155: caller is not owner nor approved."
        );

        _burnBatch(account, ids, values);
    }

    /**
     * @dev See {ERC1155-_beforeTokenTransfer}.
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal virtual override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        // if transfer is restricted on the contract, we still want to allow burning and minting
        if (!hasRole(TRANSFER_ROLE, address(0)) && from != address(0) && to != address(0)) {
            require(hasRole(TRANSFER_ROLE, from) || hasRole(TRANSFER_ROLE, to), "restricted to TRANSFER_ROLE holders.");
        }

        if (from == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                totalSupply[ids[i]] += amounts[i];
            }
        }

        if (to == address(0)) {
            for (uint256 i = 0; i < ids.length; ++i) {
                totalSupply[ids[i]] -= amounts[i];
            }
        }
    }

    ///     =====   Low level overrides  =====

    /// @dev See ERC 165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155Upgradeable, AccessControlEnumerableUpgradeable, IERC165Upgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId) || type(IERC2981Upgradeable).interfaceId == interfaceId;
    }

    function _msgSender()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (address sender)
    {
        return ERC2771ContextUpgradeable._msgSender();
    }

    function _msgData()
        internal
        view
        virtual
        override(ContextUpgradeable, ERC2771ContextUpgradeable)
        returns (bytes calldata)
    {
        return ERC2771ContextUpgradeable._msgData();
    }
}