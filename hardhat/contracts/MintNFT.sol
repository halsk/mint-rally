//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.4;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./lib/Base64.sol";

interface IEventManager {
    function applyForParticipation(uint256 _eventRecordId) external;

    function verifySecretPhrase(
        string memory _secretPhrase,
        uint256 _eventRecordId
    ) external returns (bool);

    // function isAlreadyMintedNFT(
    //     address participant,
    //     uint256 eventId
    // ) external view returns (bool);
}

contract MintNFT is ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    address private eventManagerAddr;

    function setEventManagerAddr(address _eventManagerAddr) public onlyOwner {
        eventManagerAddr = _eventManagerAddr;
    }

    struct ParticipateNFTAttributes {
        string name;
        string image;
        uint256 groupId;
        uint256 eventId;
        uint256 requiredParticipateCount;
    }

    mapping(uint256 => ParticipateNFTAttributes) public attributesOfNFT;
    mapping(uint256 => ParticipateNFTAttributes[]) private groupsNFTAttributes;

    constructor() ERC721("MintRally", "MR") {}

    function mintParticipateNFT(
        uint256 _groupId,
        uint256 _eventId,
        string memory _secretPhrase
    ) external returns (string memory) {
        ParticipateNFTAttributes[]
            memory groupNFTAttributes = groupsNFTAttributes[_groupId];

        IEventManager _eventManager = IEventManager(eventManagerAddr);
        require(
            _eventManager.verifySecretPhrase(_secretPhrase, _eventId),
            "invalid secret phrase"
        );
        // require(
        //     _eventManager.isAlreadyMintedNFT(msg.sender, _eventId),
        //     "already minted NFT on event"
        // );
        

        ParticipateNFTAttributes[] memory ownedNFTs = listNFTsByAddress(
            msg.sender
        );
        bool firstMintOnEvent = true;
        uint256 countOwnedGroupNFTs = 0;
        for (uint256 index = 0; index < ownedNFTs.length; index++) {
            ParticipateNFTAttributes memory nft = ownedNFTs[index];
            if (nft.groupId == _groupId && nft.eventId == _eventId) {
                firstMintOnEvent = false;
                break;
            }
            if (nft.groupId == _groupId) {
                countOwnedGroupNFTs++;
            }
        }
        require(
            firstMintOnEvent,
            "already minted NFT on event"
        );

        bool minted = false;
        ParticipateNFTAttributes memory defaultNFT;
        for (uint256 index = 0; index < groupNFTAttributes.length; index++) {
            ParticipateNFTAttributes memory gp = groupNFTAttributes[index];
            gp.eventId = _eventId;
            if (gp.requiredParticipateCount == 0) {
                defaultNFT = gp;
            }
            if (gp.requiredParticipateCount == countOwnedGroupNFTs) {
                attributesOfNFT[_tokenIds.current()] = gp;
                _safeMint(msg.sender, _tokenIds.current());
                minted = true;
            }
        }
        if (!minted) {
            attributesOfNFT[_tokenIds.current()] = defaultNFT;
            _safeMint(msg.sender, _tokenIds.current());
        }
        _eventManager.applyForParticipation(_eventId);
        string memory mintedTokenURI = tokenURI(_tokenIds.current());
        _tokenIds.increment();
        return mintedTokenURI;
    }

    function listNFTsByAddress(address _address)
        internal
        view
        returns (ParticipateNFTAttributes[] memory)
    {
        uint256 tokenCount = balanceOf(_address);
        uint256[] memory tokenIds = new uint256[](tokenCount);
        for (uint256 i = 0; i < tokenCount; i++) {
            tokenIds[i] = tokenOfOwnerByIndex((_address), i);
        }

        ParticipateNFTAttributes[]
            memory holdingNFTsAttributes = new ParticipateNFTAttributes[](
                tokenCount
            );
        for (uint256 i = 0; i < tokenCount; i++) {
            uint256 id = tokenIds[i];
            holdingNFTsAttributes[i] = attributesOfNFT[id];
        }
        return holdingNFTsAttributes;
    }

    function getOwnedNFTs()
        public
        view
        returns (ParticipateNFTAttributes[] memory)
    {
        ParticipateNFTAttributes[]
            memory holdingNFTsAttributes = listNFTsByAddress(msg.sender);
        return holdingNFTsAttributes;
    }

    function pushGroupNFTAttributes(
        uint256 groupId,
        ParticipateNFTAttributes[] memory attributes
    ) external {
        for (uint256 index = 0; index < attributes.length; index++) {
            groupsNFTAttributes[groupId].push(
                ParticipateNFTAttributes({
                    name: attributes[index].name,
                    image: attributes[index].image,
                    groupId: attributes[index].groupId,
                    eventId: attributes[index].eventId,
                    requiredParticipateCount: attributes[index]
                        .requiredParticipateCount
                })
            );
        }
    }

    function getGroupNFTAttributes(uint256 _groupId)
        external
        view
        returns (ParticipateNFTAttributes[] memory)
    {
        return groupsNFTAttributes[_groupId];
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        ParticipateNFTAttributes memory attributes = attributesOfNFT[_tokenId];

        string memory json = Base64.encode(
            abi.encodePacked(
                "{'name': '",
                attributes.name,
                " -- NFT #: ",
                Strings.toString(_tokenId),
                "', 'description': 'MintRally NFT', 'image': '",
                attributes.image,
                "}"
            )
        );

        string memory output = string(
            abi.encodePacked("data:application/json;base64,", json)
        );
        return output;
    }
}
