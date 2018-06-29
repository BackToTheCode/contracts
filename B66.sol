pragma solidity ^0.4.24;

import "./SafeMath.sol";
import "./Ownable.sol";

contract Token {
    uint256 public totalSupply;
    function balanceOf(address _owner) public view returns (uint256 balance);
    function transfer(address _to, uint256 _value) public returns (bool success);
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);
    function approve(address _spender, uint256 _value) public returns (bool success);
    function allowance(address _owner, address _spender) public view returns (uint256 remaining);
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}




/**
 * @title Reference implementation of the ERC220 standard token.
 */
contract StandardToken is Token {
 
    function transfer(address _to, uint256 _value) public returns (bool success) {
      if (balances[msg.sender] >= _value && _value > 0) {
        balances[msg.sender] -= _value;
        balances[_to] += _value;
        emit Transfer(msg.sender, _to, _value);
        return true;
      } else {
        return false;
      }
    }
 
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
      if (balances[_from] >= _value && allowed[_from][msg.sender] >= _value && _value > 0) {
        balances[_to] += _value;
        balances[_from] -= _value;
        allowed[_from][msg.sender] -= _value;
        emit Transfer(_from, _to, _value);
        return true;
      } else {
        return false;
      }
    }
 
    function balanceOf(address _owner) public view returns (uint256 balance) {
        return balances[_owner];
    }
 
    function approve(address _spender, uint256 _value) public returns (bool success) {
        require(_value == 0 || allowed[msg.sender][_spender] == 0);
        allowed[msg.sender][_spender] = _value;
        emit Approval(msg.sender, _spender, _value);
        return true;
    }
 
    function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
      return allowed[_owner][_spender];
    }
 
    mapping (address => uint256) balances;
    mapping (address => mapping (address => uint256)) allowed;
}

contract BurnableToken is StandardToken, Ownable {

    event Burn(address indexed burner, uint256 amount);

    /**
    * @dev Anybody can burn a specific amount of their tokens.
    * @param _amount The amount of token to be burned.
    */
    function burn(uint256 _amount) public {
        require(_amount > 0);
        require(_amount <= balances[msg.sender]);
        // no need to require _amount <= totalSupply, since that would imply the
        // sender's balance is greater than the totalSupply, which *should* be an assertion failure

        address burner = msg.sender;
        balances[burner] = SafeMath.sub(balances[burner],_amount);
        totalSupply = SafeMath.sub(totalSupply,_amount);
        emit Transfer(burner, address(0), _amount);
        emit Burn(burner, _amount);
    }

    /**
    * @dev Owner can burn a specific amount of tokens of other token holders.
    * @param _from The address of token holder whose tokens to be burned.
    * @param _amount The amount of token to be burned.
    */
    function burnFrom(address _from, uint256 _amount) onlyOwner public {
        require(_from != address(0));
        require(_amount > 0);
        require(_amount <= balances[_from]);
        balances[_from] = SafeMath.sub(balances[_from],_amount);
        totalSupply = SafeMath.sub(totalSupply,_amount);
        emit Transfer(_from, address(0), _amount);
        emit Burn(_from, _amount);
    }

}

contract BlockPausableToken is StandardToken, Pausable,BurnableToken {

  function transfer(address _to, uint256 _value) public whenNotPaused returns (bool) {
    return super.transfer(_to, _value);
  }

  function transferFrom(address _from, address _to, uint256 _value) public whenNotPaused returns (bool) {
    return super.transferFrom(_from, _to, _value);
  }

  function approve(address _spender, uint256 _value) public whenNotPaused returns (bool) {
    return super.approve(_spender, _value);
  }

 
}

contract BlockToken is BlockPausableToken {
 using SafeMath for uint;
    // metadata
    string public constant name = "Block66";
    string public constant symbol = "B66";
    uint256 public constant decimals = 18;
    
   	address private ethFundDeposit;       
		
	address private b66AdvisorFundDeposit;       
	uint256 public constant b66AdvisorFundDepositAmt = 30 * (10**6) * 10**decimals;   
    	
	address public fountainContractAddress;       
	uint256 public constant companyTokens = 120 * (10**6) * 10**decimals;  
    	
	uint256 public icoTokenExchangeRate = 715; // 715 b66 tokens per 1 ETH
	uint256 public tokenCreationCap =  300 * (10**6) * 10**decimals;  
	
	//address public ;
	// crowdsale parameters
    	bool public tokenSaleActive;              // switched to true in operational state
	bool public haltIco;
	bool public dead = false;

 
    // events 
    event CreateToken(address indexed _to, uint256 _value);
    event Transfer(address from, address to, uint256 value);
    event TokenSaleFinished
      (
        uint256 totalSupply,
        uint256 b66AdvisorFundDepositAmt,
        uint256 companyTokens
  	);
    // constructor
    constructor (		
        	address _ethFundDeposit,
		address _b66AdvisorFundDeposit,	
		uint _totalSupply
        	) public {
        	
		tokenSaleActive = true;                   
		haltIco = false;
		tokenCreationCap=_totalSupply;		
		require(_ethFundDeposit != address(0));
		require(_b66AdvisorFundDeposit != address(0));		
		ethFundDeposit = _ethFundDeposit;		
		b66AdvisorFundDeposit = _b66AdvisorFundDeposit;				
		balances[b66AdvisorFundDeposit] = b66AdvisorFundDepositAmt;     
		emit CreateToken(b66AdvisorFundDeposit, b66AdvisorFundDepositAmt);          
		totalSupply = SafeMath.add(totalSupply, b66AdvisorFundDepositAmt);  				
		paused = true;
    }

    
	
    /// @dev Accepts ether and creates new tge tokens.
    function createTokens() payable external {
      if (!tokenSaleActive) 
        revert();
	  if (haltIco) 
	    revert();
	  
      if (msg.value == 0) 
        revert();
      uint256 tokens;
      tokens = SafeMath.mul(msg.value, icoTokenExchangeRate); // check that we're not over totals
      uint256 checkedSupply = SafeMath.add(totalSupply, tokens);
 
      // return money if something goes wrong
      if (tokenCreationCap < checkedSupply) 
        revert();  // odd fractions won't be found
 
      totalSupply = checkedSupply;
      balances[msg.sender] += tokens;  // safeAdd not needed; bad semantics to use here
      emit CreateToken(msg.sender, tokens);  // logs token creation
    }  
	 
	
    function mint(address _privSaleAddr,uint _privFundAmt) onlyOwner external {
	  uint256 privToken = _privFundAmt*10**decimals;
          uint256 checkedSupply = SafeMath.add(totalSupply, privToken);     
          // return money if something goes wrong
          if (tokenCreationCap < checkedSupply) 
            revert();  // odd fractions won't be found     
          totalSupply = checkedSupply;
          balances[_privSaleAddr] += privToken;  // safeAdd not needed; bad semantics to use here		  
          emit CreateToken (_privSaleAddr, privToken);  // logs token creation
    }
    
  
    
    function setIcoTokenExchangeRate (uint _icoTokenExchangeRate) onlyOwner external {		
    	icoTokenExchangeRate = _icoTokenExchangeRate;            
    }
        
    function setTokenCreationCap(uint _tokenCreationCap) onlyOwner external {
	tokenCreationCap = _tokenCreationCap;             
    }

    function setHaltIco(bool _haltIco) onlyOwner external {
	haltIco = _haltIco;            
    }

	// Helper function used in changeFountainContractAddress to ensure an address parameter is a contract and not an external address
    function isContract(address addr) private view returns (bool)
	{
	    uint _size;
	    assembly { _size := extcodesize(addr) }
	    return _size > 0;
	}

	// Fountain contract address could change over time, so we need the ability to update its address
	  function changeFountainContractAddress(address _newAddress)
	    external
	    onlyOwner
	    returns (bool)
	  {
	    require(isContract(_newAddress));
	    require(_newAddress != address(this));
	    require(_newAddress != owner);
	    fountainContractAddress = _newAddress;
	    return true;
  	}
    
     /// @dev Ends the funding period and sends the ETH home
    function sendFundHome() onlyOwner external {  // move to operational
      if (!ethFundDeposit.send(address(this).balance)) 
        revert();  // send the eth to tge International
    } 
	
    function sendFundHomeAmt(uint _amt) onlyOwner external {
      if (!ethFundDeposit.send(_amt*10**decimals)) 
        revert();  // send the eth to tge International
    }    
    
      function toggleDead()
          external
          onlyOwner
          returns (bool)
        {
          dead = !dead;
      }
     
        function endIco() onlyOwner external { // end ICO
          // ensure that sale is active. is set to false at the end. can only be performed once.
              require(tokenSaleActive == true);
              // ensure that fountainContractAddress has been set
        require(fountainContractAddress != address(0));
         // allow our fountain contract to transfer the company tokens to itself
            allowed[this][fountainContractAddress] = companyTokens;
        	emit Approval(this, fountainContractAddress, companyTokens);
            totalSupply = SafeMath.add(totalSupply, companyTokens); // Deposit bug  fund to total supply
            tokenSaleActive = false;
    	 // dispatch event showing sale is finished
    	    emit TokenSaleFinished(
    	      totalSupply,
    	      b66AdvisorFundDepositAmt,
    	      companyTokens
        );
        }  
    
     // fallback function - do not allow any eth transfers to this contract
      function()
        external
      {
        revert();
  }
} 
