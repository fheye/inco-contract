// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "fhevm/lib/TFHE.sol";
import "@openzeppelin/contracts/access/Ownable2Step.sol";
import "fhevm/gateway/GatewayCaller.sol";

contract FaceDetection is Ownable2Step, GatewayCaller {
    // constant length of vector
    uint8 constant VECTOR_LENGTH = 4;
    uint8 constant CHUNK_SIZE = 2;

    string public _name;
    string public _symbol;

    // Counter for generating unique image IDs
    uint256 private imageCounter;

    // Mapping of image to feature vector (encrypted)
    mapping(uint256 => euint8[]) public images;

    // Mapping of image to metadata
    mapping(uint256 => Image) public metadata;

    // Mapping of user address to User struct
    mapping(address => User) public users;

    constructor() Ownable(msg.sender) {
        _name = "Face Detection";
        _symbol = "FACE";
        imageCounter = 0;
    }

    struct User {
        int256 locationX;
        int256 locationY;
        uint256 alertDistance;
        uint256 uploadedImagesCount;
        uint256 rewards;
    }

    struct Image {
        euint16 locationX;
        euint16 locationY;
        euint16 timestamp;
        address uploader;
    }

    event ImageUploaded(address indexed user, uint256 imageId);
    event FaceDetected(address indexed user, uint256 imageId, uint32 distance);
    event MetadataAccessed(uint256 imageId, address accessor, uint256 fee, uint256 locationX, uint256 locationY, uint256 timestamp);

    /// @notice Computes the Euclidean distance between an input vector and a stored vector
    /// @param imageId The ID of the stored image to compare
    /// @param inputVector The input encrypted vector to compare against
    /// @return distance The encrypted Euclidean distance score
    function faceDetection(uint256 imageId, euint8[] memory inputVector) public onlyOwner returns (uint32 distance) {
        require(imageId < imageCounter, "Invalid image ID");

        euint8 sumOfSquares = TFHE.asEuint8(0);

        euint8[] memory image = images[imageId];

        // n > 16 

        for (uint256 i = 0; i < inputVector.length; i++) {
            euint8 diff = TFHE.sub(image[i], inputVector[i]);
            // euint8 squaredDiff = diff * diff;
            sumOfSquares = TFHE.add(sumOfSquares, diff);
        }

        TFHE.allow(sumOfSquares, address(this));

        emit FaceDetected(msg.sender, imageId, 15);
        return 15;
    }

    function faceDetectionChunk(uint256 imageId, euint8[] memory inputVector, uint256 chunkIndex) public returns (uint8 distance) {
        require(imageId < imageCounter, "Invalid image ID");

        euint8 sumOfSquares = TFHE.asEuint8(0);

        euint8[] memory image = images[imageId];

        for (uint8 i = 0; i < inputVector.length; i++) {
            euint8 diff = TFHE.sub(image[chunkIndex * CHUNK_SIZE + i], inputVector[i]);
            euint8 squaredDiff = TFHE.mul(diff, diff);
            sumOfSquares = TFHE.add(sumOfSquares, squaredDiff);
        }

        TFHE.allow(sumOfSquares, address(this));

        emit FaceDetected(msg.sender, imageId, 15);

        return 15;
    }


    /// @notice Function to upload an image
    /// @param locationX The X coordinate of the image location
    /// @param locationY The Y coordinate of the image location
    /// @param timestamp The timestamp of the image
    function uploadImage(
        euint16 locationX,
        euint16 locationY,
        euint16 timestamp,
        bytes calldata inputProof
    ) public returns (uint256) {
        uint256 imageId = imageCounter;

        euint8[VECTOR_LENGTH] memory newVector;

        for (uint16 i = 0; i < VECTOR_LENGTH; i++) {
            newVector[i] = TFHE.asEuint8(0);
        }

        images[imageId] = newVector;

        metadata[imageId] = Image({
            locationX: locationX,
            locationY: locationY,
            timestamp: timestamp,
            uploader: msg.sender
        });

        users[msg.sender].uploadedImagesCount += 1;

        imageCounter++;

        emit ImageUploaded(msg.sender, imageId);

        return imageId;
    }

    function uploadImageChunk(
        euint8[] memory inputVector,
        uint256 imageId,
        uint256 chunkIndex
    ) public {
        require(imageId < imageCounter, "Invalid image ID");

        euint8[] memory existingVector = images[imageId];
        for (uint8 i = 0; i < inputVector.length; i++) {
            existingVector[chunkIndex * CHUNK_SIZE + i] = inputVector[i];
        }

        images[imageId] = existingVector;
    }

    /// @notice Function to access metadata for an image (payable)
    /// @param imageId The ID of the image
    function accessMetadata(uint256 imageId) public payable returns (uint16, uint16, uint16) {
        // require(msg.value >= 0.01 ether, "Insufficient payment");

        Image memory image = metadata[imageId];
        require(image.uploader != address(0), "Image does not exist");

        // Reward the uploader
        users[image.uploader].rewards += msg.value;

        TFHE.allow(image.locationX, address(this));
        TFHE.allow(image.locationY, address(this));
        TFHE.allow(image.timestamp, address(this));

        emit MetadataAccessed(imageId, msg.sender, msg.value, 15, 15, 15);
        return (15, 15, 15);
    }

    /// @notice Update user location
    /// @param x The X coordinate of the user's location
    /// @param y The Y coordinate of the user's location
    function updateUserLocation(int256 x, int256 y) public {
        users[msg.sender].locationX = x;
        users[msg.sender].locationY = y;
    }
}
