// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract WETH9 {
    string public name     = "Wrapped Ether";
    string public symbol   = "WETH";
    uint8  public decimals = 18;

    event  Approval(address indexed owner, address indexed spender, uint value);
    event  Transfer(address indexed from, address indexed to, uint value);

    mapping(address => uint)                       public  balanceOf;
    mapping(address => mapping(address => uint))   public  allowance;

    receive() external payable {
        deposit();
    }

    function deposit() public payable {
        balanceOf[msg.sender] += msg.value;
        emit Transfer(address(0), msg.sender, msg.value);
    }

    function withdraw(uint value) public {
        require(balanceOf[msg.sender] >= value);
        balanceOf[msg.sender] -= value;
        payable(msg.sender).transfer(value);
        emit Transfer(msg.sender, address(0), value);
    }

    function totalSupply() public view returns (uint) {
        return address(this).balance;
    }

    function approve(address spender, uint value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transfer(address to, uint value) public returns (bool) {
        return transferFrom(msg.sender, to, value);
    }

    function transferFrom(address from, address to, uint value)
        public
        returns (bool)
    {
        require(balanceOf[from] >= value);

        if (from != msg.sender && allowance[from][msg.sender] != type(uint).max) {
            require(allowance[from][msg.sender] >= value);
            allowance[from][msg.sender] -= value;
        }

        balanceOf[from] -= value;
        balanceOf[to] += value;

        emit Transfer(from, to, value);

        return true;
    }
}