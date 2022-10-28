// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.0;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {LSSVMPair} from "./LSSVMPair.sol";
import {ILSSVMPairFactoryLike} from "./ILSSVMPairFactoryLike.sol";
import {ICurve} from "./bonding-curves/ICurve.sol";

/**
    @title An NFT/Token pair for an NFT that does not implement ERC721Enumerable
    @author boredGenius and 0xmons
 */
abstract contract LSSVMPairMissingEnumerable is LSSVMPair {
    using EnumerableSet for EnumerableSet.UintSet;

    // Used for internal ID tracking
    EnumerableSet.UintSet private idSet;
    bool public isSudoMirror;
    address public sudoPoolAddress;

    mapping(uint256 => address) permissionedIds;

    /// @inheritdoc LSSVMPair
    function _sendAnyNFTsToRecipient(
        IERC721 _nft,
        address nftRecipient,
        uint256 numNFTs
    ) internal override {
        // Send NFTs to recipient
        // We're missing enumerable, so we also update the pair's own ID set
        // NOTE: We start from last index to first index to save on gas
        require(_nft == nft());
        uint256 lastIndex = idSet.length() - 1;
        for (uint256 i; i < numNFTs; ) {
            uint256 nftId = idSet.at(lastIndex);
            uint256[] memory nftIds;
            nftIds[0] = nftId;
            if (isSudoMirror) {
                // TODO: move this out of the loop
                LSSVMPairMissingEnumerable(sudoPoolAddress).withdrawERC721(_nft, nftIds);
                _nft.safeTransferFrom(address(this), nftRecipient, nftId);
            } else {
                ILSSVMPairFactoryLike(address(factory())).requestNFTTransferFrom(_nft, permissionedIds[nftId], nftRecipient, nftId);
            }
            
            idSet.remove(nftId);
            permissionedIds[nftId] = address(0);
            unchecked {
                --lastIndex;
                ++i;
            }
        }
    }

    /// @inheritdoc LSSVMPair
    function _sendSpecificNFTsToRecipient(
        IERC721 _nft,
        address nftRecipient,
        uint256[] calldata nftIds
    ) internal override {
        // Send NFTs to caller
        // If missing enumerable, update pool's own ID set
        require(_nft == nft());
        if (isSudoMirror) LSSVMPairMissingEnumerable(sudoPoolAddress).withdrawERC721(_nft, nftIds);
        uint256 numNFTs = nftIds.length;
        for (uint256 i; i < numNFTs; ) {
            if (isSudoMirror) {
                _nft.safeTransferFrom(
                    address(this),
                    nftRecipient,
                    nftIds[i]
                );
            } else {
                ILSSVMPairFactoryLike(address(factory())).requestNFTTransferFrom(_nft, permissionedIds[nftIds[i]], nftRecipient, nftIds[i]);
            }
            
            // Remove from id set
            idSet.remove(nftIds[i]);
            permissionedIds[nftIds[i]] = address(0);
            unchecked {
                ++i;
            }
        }
    }

    function changeDelta(uint128 newDelta) external override onlyOwner {
        ICurve _bondingCurve = bondingCurve();
        require(
            _bondingCurve.validateDelta(newDelta),
            "Invalid delta for curve"
        );
        if (delta != newDelta) {
            delta = newDelta;
            emit DeltaUpdate(newDelta);
        }
        if (isSudoMirror) LSSVMPairMissingEnumerable(sudoPoolAddress).changeDelta(newDelta);
    }

    function changeSpotPrice(uint128 newSpotPrice) external override onlyOwner {
        ICurve _bondingCurve = bondingCurve();
        require(
            _bondingCurve.validateSpotPrice(newSpotPrice),
            "Invalid new spot price for curve"
        );
        if (spotPrice != newSpotPrice) {
            spotPrice = newSpotPrice;
            emit SpotPriceUpdate(newSpotPrice);
        }
        if (isSudoMirror) return LSSVMPairMissingEnumerable(sudoPoolAddress).changeSpotPrice(newSpotPrice);
    }

    /// @inheritdoc LSSVMPair
    function getAllHeldIds() external view override returns (uint256[] memory) {
        if (isSudoMirror) return LSSVMPairMissingEnumerable(sudoPoolAddress).getAllHeldIds();
        uint256 numNFTs = idSet.length();
        uint256[] memory ids = new uint256[](numNFTs);
        uint256 y = 0;
        for (uint256 i; i < numNFTs; ) {
            if (
                nft().isApprovedForAll(
                    permissionedIds[idSet.at(i)],
                    address(factory())
                ) && nft().ownerOf(idSet.at(i)) == permissionedIds[idSet.at(i)]
            ) {
                ids[y] = idSet.at(i);
                unchecked {
                    ++y;
                }
            }
            unchecked {
                ++i;
            }
        }
        uint256[] memory idsCopy = new uint256[](y + 1);
        for (uint256 i; i < y; ) {
            idsCopy[i] = ids[i];
            unchecked {
                ++i;
            }
        }
        return idsCopy;
    }

    function addNFTToPool(uint256[] calldata ids) external {
        for (uint256 i; i < ids.length; i++) {
            address nftOwner = nft().ownerOf(ids[i]);
            // if(nft().isApprovedForAll(nftOwner, address(this)) && nftOwner == msg.sender) {
            idSet.add(ids[i]);
            if (!isSudoMirror) {
                permissionedIds[ids[i]] = nftOwner;
            }
            if (isSudoMirror) {
              ILSSVMPairFactoryLike(address(factory())).requestNFTTransferFrom(nft(), nftOwner, sudoPoolAddress, ids[i]);
            }
            
            // emit event
        }
    }

    function removeNFTFromPool(uint256[] calldata ids) external onlyOwner {
        if (isSudoMirror) LSSVMPairMissingEnumerable(sudoPoolAddress).withdrawERC721(nft(), ids);
        for (uint256 i; i < ids.length; i++) {
            // address nftOwner = nft().ownerOf(ids[i]);
            // if (nftOwner == msg.sender) {
            idSet.remove(ids[i]);
            permissionedIds[ids[i]] = address(0);
            if (isSudoMirror) {
              nft().safeTransferFrom(address(this), permissionedIds[ids[i]], ids[i]);
            }
            // }
            // emit event
        }
    }

    function createSudoPool(
      address factoryAddress,
        address payable _assetRecipient) external payable returns (address){
          require(sudoPoolAddress == address(0), "Sudo Pool Already Initialized");
          uint256[] memory arr;
          isSudoMirror = true;
          sudoPoolAddress = address(ILSSVMPairFactoryLike(factoryAddress).createPairETH{value: msg.value}(address(nft()), address(bondingCurve()), _assetRecipient, uint8(poolType()), delta, fee, spotPrice, arr));
        return sudoPoolAddress;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC721Received.selector;
    }

    function removeStaleNFTs() public {
        uint256 numNFTs = idSet.length();
        for (uint256 i; i < numNFTs; ) {
            if (
                !nft().isApprovedForAll(
                    permissionedIds[idSet.at(i)],
                    address(this)
                ) || nft().ownerOf(idSet.at(i)) != permissionedIds[idSet.at(i)]
            ) {
                idSet.remove(idSet.at(i));
                permissionedIds[idSet.at(i)] = address(0);
            }
        }
        // emit event
    }

    /// @inheritdoc LSSVMPair
    function withdrawERC721(IERC721 a, uint256[] calldata nftIds)
        external
        override
        onlyOwner
    {
        IERC721 _nft = nft();
        require(a != _nft);
        uint256 numNFTs = nftIds.length;

        // If it's not the pair's NFT, just withdraw normally
        if (a != _nft) {
            for (uint256 i; i < numNFTs; ) {
                a.safeTransferFrom(address(this), msg.sender, nftIds[i]);

                unchecked {
                    ++i;
                }
            }
        }
        // Otherwise, withdraw and also remove the ID from the ID set
        else {
            for (uint256 i; i < numNFTs; ) {
                _nft.safeTransferFrom(address(this), msg.sender, nftIds[i]);
                idSet.remove(nftIds[i]);

                unchecked {
                    ++i;
                }
            }

            emit NFTWithdrawal();
        }
    }
}
