// SPDX-License-Identifier: MIT
pragma solidity =0.8.17;

import "forge-std/console.sol";
import {VaultManagerTestHelper} from "./VaultManagerHelper.t.sol";
import {IVaultManager} from "../src/interfaces/IVaultManager.sol";

contract VaultManagerTest is VaultManagerTestHelper {

  ///////////////////////////
  // add
  function test_add() public {
    uint id = mintDNft();
    vaultManager.add(id, address(wethVault));
    assertEq(vaultManager.getVaults(id)[0], address(wethVault));
  }

  function test_addTwoVaults() public {
    uint id = mintDNft();
    addVault(id, RANDOM_VAULT_1);
    addVault(id, RANDOM_VAULT_2);
    assertEq(vaultManager.getVaults(id)[0], RANDOM_VAULT_1);
    assertEq(vaultManager.getVaults(id)[1], RANDOM_VAULT_2);
    address[] memory vaults = vaultManager.getVaults(id);
    vm.expectRevert();
    vaults[2]; // out of bounds
  }

  function testCannot_add_exceptForDNftOwner() public {
    uint id = mintDNft();
    vm.prank(address(1));
    vm.expectRevert(IVaultManager.NotOwner.selector);
    vaultManager.add(id, address(wethVault));
  }

  function testFail_add_moreThanMaxNumberOfVaults() public {
    uint id = mintDNft();

    for (uint i = 0; i < vaultManager.MAX_VAULTS(); i++) {
      addVault(id, address(uint160(i)));
    }
    // this puts it exactly one over the limit and should fail
    addVault(id, RANDOM_VAULT_1); 
  }

  function testCannot_add_unlicensedVault() public {
    uint id = mintDNft();
    vm.expectRevert(IVaultManager.VaultNotLicensed.selector);
    vaultManager.add(id, RANDOM_VAULT_1);
  }

  function testFail_cannotAddSameVaultTwice() public {
    uint id = mintDNft();
    addVault(id, RANDOM_VAULT_1);
    addVault(id, RANDOM_VAULT_1);
  }

  ///////////////////////////
  // remove
  function test_remove() public {
    uint id = mintDNft();
    vaultManager.add(id, address(wethVault));
    vaultManager.remove(id, address(wethVault));
  }

  function testCannot_remove_exceptForDNftOwner() public {
    uint id = mintDNft();
    vaultManager.add(id, address(wethVault));
    vm.prank(address(1));
    vm.expectRevert(IVaultManager.NotOwner.selector);
    vaultManager.remove(id, address(wethVault));
  }

  ///////////////////////////
  // deposit
  function test_deposit() public {
    uint id = mintDNft();
    uint AMOUNT = 1e18;
    deposit(weth, id, address(wethVault), AMOUNT);
    assertEq(wethVault.id2asset(id), AMOUNT);
  }

  function test_depositMultipleCollateralTypes() public {
    uint id = mintDNft();

    uint WETH_AMOUNT = 1e18;
    deposit(weth, id, address(wethVault), WETH_AMOUNT);
    assertEq(wethVault.id2asset(id), WETH_AMOUNT);

    uint DAI_AMOUNT = 22e16;
    deposit(dai, id, address(daiVault), DAI_AMOUNT);
    assertEq(daiVault.id2asset(id), DAI_AMOUNT);
  }

  ///////////////////////////
  // withdraw
  function test_withdraw() public {
    uint id = mintDNft();
    deposit(weth, id, address(wethVault), 1e18);
    vaultManager.withdraw(id, address(wethVault), 1e18, RECEIVER);
  }

  ///////////////////////////
  // mintDyad
  function test_mintDyad() public {
    uint id = mintDNft();
    deposit(weth, id, address(wethVault), 1e22);
    vaultManager.mintDyad(id, 1e20, RECEIVER);
  }

  ///////////////////////////
  // burnDyad
  function test_burnDyad() public {
    uint id = mintDNft();
    deposit(weth, id, address(wethVault), 1e22);
    vaultManager.mintDyad(id, 1e20, address(this));
    vaultManager.burnDyad(id, 1e20);
  }

  ///////////////////////////
  // redeemDyad
  function test_redeemDyad() public {
    uint id = mintDNft();
    deposit(weth, id, address(wethVault), 1e22);
    vaultManager.mintDyad(id, 1e20, address(this));
    vaultManager.redeemDyad(id, address(wethVault), 1e20, RECEIVER);
  }

  ///////////////////////////
  // collatRatio
  function test_collatRatio() public {
    uint id = mintDNft();
    uint cr = vaultManager.collatRatio(id);
    assertEq(cr, type(uint).max);
    deposit(weth, id, address(wethVault), 1e22);
    vaultManager.mintDyad(id, 1e24, address(this));
    cr = vaultManager.collatRatio(id);
    assertEq(cr, 10000000000000000000);
  }

  ///////////////////////////
  // getTotalUsdValue
  function test_getTotalUsdValue() public {
    uint id = mintDNft();
    uint DEPOSIT = 1e22;
    deposit(weth, id, address(wethVault), DEPOSIT);
    uint usdValue = vaultManager.getTotalUsdValue(id);
    assertEq(usdValue, 10000000000000000000000000);

    deposit(dai, id, address(daiVault), DEPOSIT);
    usdValue = vaultManager.getTotalUsdValue(id);
    assertEq(usdValue, 10000100000000000000000000);
  }

  ///////////////////////////
  // This can be exploited where users can call both VaultManagerV2::addKerosene and VaultManagerV2::add functions with their id and the weth vault as parameters. The VaultManagerV2::collatRatio uses both vaults and vaultsKerosene mapping to calculate the value of the stored assets. Since, weth vault is added in both mappings the assets be counted twice.
    // function test_CanMintSameAmountAsDeposit() public {
    //     // address RECEIVER2 = makeAddr("Receiver2");
    //     uint256 id = mintDNft(); 
    //     uint256 id2 = mintDNft();

    //     // Add vault in both contracts
    //     vaultManagerV2.add(id, address(wethVaultV2));
    //     vaultManagerV2.add(id2, address(wethVaultV2));
    //     vaultManagerV2.addKerosene(id, address(wethVaultV2));

    //     // Deposits 1e25 USD of Weth
    //     depositV2(weth, id, address(wethVaultV2), 1e22);// Price weth 1000

    //     // Mint 1e25
    //     vaultManagerV2.mintDyad(id, 1e25, RECEIVER);

    //     // Protocol considers that User has deposited twice the amount in the collateral ratio calculation
    //     console.log("CR of position", vaultManagerV2.collatRatio(id)); // 200%

    //     // Position is not liquidatable even if it is only collateralized at 100%
    //     vm.expectRevert(IVaultManager.CrTooHigh.selector);
    //     vm.prank(RECEIVER);
    //     vaultManagerV2.liquidate(id, id2);
    // }

  ///////////////////////////
  // a user can also register his ID and the keroseneVault as a normal vault because the script calls the licensing function for the kerosineVaults using the VaultLicenser rather than the kerosineManager. This can lead to positions entirely collateralized with kerosene token. Which is not what protocol intends to do and is very risky as the kerosene token is endogenous and has a manipulable asset price. 
    // function test_addKeroseneAsExoColl() public {
    //     uint256 id = mintDNft();
    //     uint256 id2 = mintDNft();

    //     // Follow script deployment. Weth Vault is licensed in both VaultManager and KerosineManager
    //     // A user can just add his id and the WethVault in the kerosine mapping and kerosineVault in the vault mapping
    //     vaultManagerV2.addKerosene(id, address(wethVaultV2));
    //     vaultManagerV2.add(id, address(unboundedKerosineVault));

    //     // Assume weth was deposited by other users
    //     depositV2(weth, id2, address(wethVaultV2), 1e24); //weth 1000 Usd

    //     // User deposits kerosine using id
    //     kerosineMock.mint(address(this), 1e20);
    //     kerosineMock.approve(address(vaultManagerV2), 1e20);
    //     vaultManagerV2.deposit(id, address(unboundedKerosineVault), 1e20);
    //     console.log("Kerosine price", unboundedKerosineVault.assetPrice()); //9999

    //     //Then mint dyad
    //     vaultManagerV2.mintDyad(id, 1e19, RECEIVER);

    //     // => Position 150% collateralized with kerosine tokens
    //     // !! User cannot add kerosine bounded or unbounded vaults in the kerosine mapping in the vault Manager
    //     // !! and id and weth vault can be added in both kerosene and normal vaults which would make the amount deposited calculated twice in the collateralRatio
    // }

}

